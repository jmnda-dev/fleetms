defmodule Fleetms.Reports do
  @moduledoc """
  Read-only report data for an organization, shaped for both an on-screen table and a
  CSV/print export. Like `Fleetms.Dashboard`, this is a thin, tenant-scoped reporting
  layer — it only reads, always within one organization's schema, and never mutates.

  Money is summed in the organization's **default currency**; line items recorded in a
  different currency are left out of the totals (currencies can't be added together),
  matching the dashboard and the `Costs` module's per-currency design. Callers render
  amounts/dates through `Fleetms.Format`.
  """
  require Ash.Query

  alias Fleetms.Expenses.Expense
  alias Fleetms.FuelManagement.FuelEntry
  alias Fleetms.Maintenance.WorkOrder
  alias Fleetms.VehicleManagement.Vehicle

  @doc """
  Maintenance & cost history: the work orders whose issue date falls in the range,
  with their parts/labour/total cost, plus a summary. `filters` keys (all optional):

    * `:from`, `:to` — `Date`s bounding `issued_at` (default: last 3 months → today)
    * `:vehicle_id` — limit to one vehicle
    * `:status` — limit to `:open` / `:in_progress` / `:completed`

  Returns `%{rows: [...], summary: %{...}, currency: code, filters: normalized}`.
  """
  def maintenance_report(scope, filters \\ %{}) do
    filters = normalize_filters(filters)
    currency = scope.organization.currency
    {from_dt, to_dt} = day_bounds(filters.from, filters.to)

    work_orders =
      WorkOrder
      |> Ash.Query.filter(is_nil(archived_at) and issued_at >= ^from_dt and issued_at <= ^to_dt)
      |> filter_vehicle(filters.vehicle_id)
      |> filter_status(filters.status)
      |> Ash.Query.load([
        :vehicle,
        work_order_service_tasks: [:work_order_service_task_parts, :labor_items]
      ])
      |> Ash.Query.sort(issued_at: :desc)
      |> read(scope)

    rows = Enum.map(work_orders, &maintenance_row(&1, currency))

    summary = %{
      count: length(rows),
      parts: sum(rows, & &1.parts),
      labour: sum(rows, & &1.labour),
      total: sum(rows, & &1.total)
    }

    %{rows: rows, summary: summary, currency: currency, filters: filters}
  end

  defp maintenance_row(work_order, currency) do
    tasks = work_order.work_order_service_tasks
    parts = tasks |> Enum.flat_map(& &1.work_order_service_task_parts) |> sum_subtotals(currency)
    labour = tasks |> Enum.flat_map(& &1.labor_items) |> sum_subtotals(currency)

    %{
      id: work_order.id,
      number: work_order.work_order_number,
      vehicle: work_order.vehicle && work_order.vehicle.name,
      issued_at: work_order.issued_at,
      completed_at: work_order.completed_at,
      status: work_order.status,
      task_count: length(tasks),
      parts: parts,
      labour: labour,
      total: Decimal.add(parts, labour)
    }
  end

  @doc """
  Cost of ownership per vehicle over a period: maintenance spend (completed work orders),
  fuel spend, their total, the distance covered, and cost per distance-unit. Only vehicles
  with activity in the range appear, worst (highest total) first. `filters` keys:

    * `:from`, `:to` — `Date`s (default: last 12 months → today)
    * `:vehicle_id` — limit to one vehicle

  Distance is approximated from the span of fuel-log odometer readings in the period (the
  best signal available until a dedicated meter history exists); a vehicle with fewer than
  two readings has no distance, so no cost-per-distance. Amounts are Decimals in the org's
  default currency; distance is canonical km. Returns
  `%{rows: [...], summary: %{...}, currency: code, filters: normalized}`.
  """
  def cost_of_ownership_report(scope, filters \\ %{}) do
    filters = normalize_range(filters, 365)
    currency = scope.organization.currency
    {from_dt, to_dt} = day_bounds(filters.from, filters.to)

    maintenance = maintenance_by_vehicle(scope, currency, from_dt, to_dt, filters.vehicle_id)
    fuel = fuel_by_vehicle(scope, currency, from_dt, to_dt, filters.vehicle_id)
    expenses = expenses_by_vehicle(scope, currency, filters.from, filters.to, filters.vehicle_id)

    names =
      vehicle_names(
        scope,
        Map.keys(maintenance) ++ Map.keys(fuel) ++ Map.keys(expenses)
      )

    rows =
      names
      |> Enum.map(fn {id, name} ->
        m = Map.get(maintenance, id, Decimal.new(0))
        {f, distance} = Map.get(fuel, id, {Decimal.new(0), nil})
        e = Map.get(expenses, id, Decimal.new(0))

        %{
          id: id,
          vehicle: name,
          maintenance: m,
          fuel: f,
          expenses: e,
          total: m |> Decimal.add(f) |> Decimal.add(e),
          distance: distance
        }
      end)
      |> Enum.sort_by(& &1.total, &(Decimal.compare(&1, &2) != :lt))

    summary = %{
      count: length(rows),
      maintenance: sum(rows, & &1.maintenance),
      fuel: sum(rows, & &1.fuel),
      expenses: sum(rows, & &1.expenses),
      total: sum(rows, & &1.total),
      distance:
        rows
        |> Enum.map(& &1.distance)
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    }

    %{rows: rows, summary: summary, currency: currency, filters: filters}
  end

  # Expense spend per vehicle in the default currency (entries in another currency
  # are left out, as they can't be summed against it).
  defp expenses_by_vehicle(scope, currency, from_date, to_date, vehicle_id) do
    Expense
    |> Ash.Query.filter(
      is_nil(archived_at) and expense_date >= ^from_date and expense_date <= ^to_date
    )
    |> filter_vehicle(vehicle_id)
    |> Ash.Query.select([:vehicle_id, :amount])
    |> read(scope)
    |> Enum.group_by(& &1.vehicle_id)
    |> Map.new(fn {id, entries} -> {id, expense_total(entries, currency)} end)
  end

  defp expense_total(entries, currency) do
    entries
    |> Enum.map(& &1.amount)
    |> Enum.filter(fn money -> money && to_string(money.currency) == currency end)
    |> Enum.map(& &1.amount)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  # Completed-work-order spend per vehicle, in the default currency.
  defp maintenance_by_vehicle(scope, currency, from_dt, to_dt, vehicle_id) do
    WorkOrder
    |> Ash.Query.filter(
      is_nil(archived_at) and status == :completed and not is_nil(completed_at) and
        completed_at >= ^from_dt and completed_at <= ^to_dt
    )
    |> filter_vehicle(vehicle_id)
    |> Ash.Query.load(work_order_service_tasks: [:work_order_service_task_parts, :labor_items])
    |> read(scope)
    |> Enum.group_by(& &1.vehicle_id, &work_order_total(&1, currency))
    |> Map.new(fn {id, totals} -> {id, Enum.reduce(totals, Decimal.new(0), &Decimal.add/2)} end)
  end

  defp work_order_total(work_order, currency) do
    work_order.work_order_service_tasks
    |> Enum.flat_map(&(&1.work_order_service_task_parts ++ &1.labor_items))
    |> sum_subtotals(currency)
  end

  # Fuel spend (default currency) and distance (odometer span) per vehicle.
  defp fuel_by_vehicle(scope, currency, from_dt, to_dt, vehicle_id) do
    FuelEntry
    |> Ash.Query.filter(is_nil(archived_at) and refueled_at >= ^from_dt and refueled_at <= ^to_dt)
    |> filter_vehicle(vehicle_id)
    |> Ash.Query.select([:vehicle_id, :cost, :odometer])
    |> read(scope)
    |> Enum.group_by(& &1.vehicle_id)
    |> Map.new(fn {id, entries} ->
      {id, {fuel_cost(entries, currency), odometer_span(entries)}}
    end)
  end

  defp fuel_cost(entries, currency) do
    entries
    |> Enum.map(& &1.cost)
    |> Enum.filter(fn money -> money && to_string(money.currency) == currency end)
    |> Enum.map(& &1.amount)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  # Distance covered ≈ highest odometer − lowest, needing at least two readings.
  defp odometer_span(entries) do
    odometers = entries |> Enum.map(& &1.odometer) |> Enum.reject(&is_nil/1)

    if length(odometers) >= 2 do
      sorted = Enum.sort(odometers, &(Decimal.compare(&1, &2) != :gt))
      Decimal.sub(List.last(sorted), List.first(sorted))
    end
  end

  defp vehicle_names(_scope, []), do: []

  defp vehicle_names(scope, ids) do
    ids = Enum.uniq(ids)

    Vehicle
    |> Ash.Query.filter(id in ^ids)
    |> Ash.Query.select([:id, :name])
    |> read(scope)
    |> Enum.map(&{&1.id, &1.name})
  end

  @doc """
  Fuel & economy: fuel entries in the range (newest first) with per-entry economy, plus a
  summary. Economy for an entry is that fill's fuel over the distance since the vehicle's
  previous fill (tank-to-tank), so the first entry per vehicle has none. Returns rows with
  `economy: %{distance_km, fuel_l} | nil` for the caller to format per the org's units.
  `filters`: `:from`, `:to` (default last 3 months), `:vehicle_id`.
  """
  def fuel_report(scope, filters \\ %{}) do
    filters = normalize_range(filters, 90)
    currency = scope.organization.currency
    {from_dt, to_dt} = day_bounds(filters.from, filters.to)

    entries =
      FuelEntry
      |> Ash.Query.filter(
        is_nil(archived_at) and refueled_at >= ^from_dt and refueled_at <= ^to_dt
      )
      |> filter_vehicle(filters.vehicle_id)
      |> Ash.Query.load(vehicle: [:name])
      |> read(scope)

    rows =
      entries
      |> Enum.group_by(& &1.vehicle_id)
      |> Enum.flat_map(fn {_id, ves} -> ves |> chronological() |> with_economy() end)
      |> Enum.sort_by(& &1.date, {:desc, DateTime})

    economies = rows |> Enum.map(& &1.economy) |> Enum.reject(&is_nil/1)

    summary = %{
      count: length(rows),
      quantity: sum(rows, & &1.quantity),
      cost:
        rows
        |> Enum.filter(&(&1.cost && to_string(&1.cost.currency) == currency))
        |> sum(& &1.cost.amount),
      distance: economies |> sum(& &1.distance_km),
      fuel: economies |> sum(& &1.fuel_l)
    }

    %{rows: rows, summary: summary, currency: currency, filters: filters}
  end

  defp chronological(entries), do: Enum.sort_by(entries, & &1.refueled_at, DateTime)

  # Walk a vehicle's chronological entries, attaching each fill's economy from the
  # distance since the previous fill.
  defp with_economy(entries) do
    {rows, _prev} =
      Enum.map_reduce(entries, nil, fn e, prev_odometer ->
        {fuel_row(e, economy_since(prev_odometer, e)), e.odometer || prev_odometer}
      end)

    rows
  end

  defp economy_since(%Decimal{} = prev, %{odometer: %Decimal{} = odo, quantity: qty}) do
    delta = Decimal.sub(odo, prev)
    if Decimal.compare(delta, Decimal.new(0)) == :gt, do: %{distance_km: delta, fuel_l: qty}
  end

  defp economy_since(_prev, _entry), do: nil

  defp fuel_row(entry, economy) do
    %{
      id: entry.id,
      date: entry.refueled_at,
      vehicle: entry.vehicle && entry.vehicle.name,
      quantity: entry.quantity,
      cost: entry.cost,
      odometer: entry.odometer,
      economy: economy
    }
  end

  @doc """
  Vehicle roster: the fleet with its identifying and status fields, sorted by name.
  `filters`: `:status` (an atom/string matching `VehicleStatus`) limits by status.
  Returns `%{rows: [...], summary: %{count}, filters}`.
  """
  def vehicle_roster(scope, filters \\ %{}) do
    status = roster_status(get(filters, :status))

    vehicles =
      Vehicle
      |> roster_filter_status(status)
      |> Ash.Query.load(vehicle_model: [:vehicle_make])
      |> Ash.Query.sort(name: :asc)
      |> read(scope)

    rows = Enum.map(vehicles, &roster_row/1)

    %{rows: rows, summary: %{count: length(rows)}, filters: %{status: status}}
  end

  defp roster_row(v) do
    %{
      id: v.id,
      name: v.name,
      make: v.vehicle_model && v.vehicle_model.vehicle_make && v.vehicle_model.vehicle_make.name,
      model: v.vehicle_model && v.vehicle_model.name,
      status: v.status,
      license_plate: v.license_plate,
      vin: v.vin,
      year: v.year,
      mileage: v.mileage,
      purchase_date: v.purchase_date
    }
  end

  defp roster_filter_status(query, nil), do: query
  defp roster_filter_status(query, status), do: Ash.Query.filter(query, status == ^status)

  defp roster_status(nil), do: nil
  defp roster_status(""), do: nil
  defp roster_status(status) when is_atom(status), do: status

  defp roster_status(status) when is_binary(status) do
    Enum.find(Fleetms.VehicleManagement.VehicleStatus.values(), &(to_string(&1) == status))
  end

  # --- filter helpers ---

  defp filter_vehicle(query, nil), do: query
  defp filter_vehicle(query, ""), do: query
  defp filter_vehicle(query, id), do: Ash.Query.filter(query, vehicle_id == ^id)

  defp filter_status(query, nil), do: query
  defp filter_status(query, status), do: Ash.Query.filter(query, status == ^status)

  # --- shared helpers ---

  @doc """
  A date range + optional vehicle filter, with the range defaulting to the last
  `default_days` days (accepts string or atom keys).
  """
  def normalize_range(filters, default_days) do
    today = Date.utc_today()

    %{
      from: to_date(get(filters, :from), Date.add(today, -default_days)),
      to: to_date(get(filters, :to), today),
      vehicle_id: blank_to_nil(get(filters, :vehicle_id))
    }
  end

  @doc "Applies sensible defaults to a raw filter map (accepts string or atom keys)."
  def normalize_filters(filters) do
    today = Date.utc_today()

    %{
      from: to_date(get(filters, :from), Date.add(today, -90)),
      to: to_date(get(filters, :to), today),
      vehicle_id: blank_to_nil(get(filters, :vehicle_id)),
      status: to_status(get(filters, :status))
    }
  end

  defp read(query, scope),
    do: query |> scope_to_owner(scope) |> Ash.read!(tenant: scope.organization, authorize?: false)

  # Reports run with `authorize?: false`, so in the shared individuals pool they
  # must be scoped to the relevant client's `owner_id` (only for owner-scoped
  # resources); otherwise a client's report would span every client in the pool.
  # Mirrors `Fleetms.Dashboard`.
  defp scope_to_owner(query, scope) do
    q = Ash.Query.new(query)

    with owner when not is_nil(owner) <- Fleetms.Individuals.acting_owner_id(scope),
         true <- not is_nil(Ash.Resource.Info.attribute(q.resource, :owner_id)) do
      Ash.Query.filter(q, owner_id == ^owner)
    else
      _ -> query
    end
  end

  # Sum the subtotals in `currency` across a set of line items, as a Decimal.
  defp sum_subtotals(lines, currency) do
    lines
    |> Enum.map(& &1.subtotal)
    |> Enum.filter(fn money -> money && to_string(money.currency) == currency end)
    |> Enum.map(& &1.amount)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp sum(rows, fun), do: Enum.reduce(rows, Decimal.new(0), &Decimal.add(fun.(&1), &2))

  # The range as UTC datetimes covering the whole of both days.
  defp day_bounds(from, to) do
    {:ok, from_dt} = DateTime.new(from, ~T[00:00:00], "Etc/UTC")
    {:ok, to_dt} = DateTime.new(to, ~T[23:59:59], "Etc/UTC")
    {from_dt, to_dt}
  end

  defp get(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))

  defp to_date(%Date{} = date, _default), do: date

  defp to_date(value, default) when is_binary(value) and value != "" do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> default
    end
  end

  defp to_date(_value, default), do: default

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp to_status(status) when status in [:open, :in_progress, :completed], do: status

  defp to_status(status) when is_binary(status) do
    case status do
      "open" -> :open
      "in_progress" -> :in_progress
      "completed" -> :completed
      _ -> nil
    end
  end

  defp to_status(_), do: nil
end
