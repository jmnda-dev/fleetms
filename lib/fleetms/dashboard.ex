defmodule Fleetms.Dashboard do
  @moduledoc """
  Read-only summary figures for an organization's home dashboard.

  This is a thin reporting layer over the domain resources: it runs a handful of
  tenant-scoped counts and returns a plain map the dashboard LiveView renders. It is
  deliberately not an Ash domain — it only reads, and always within one organization's
  schema.

  Counts run with `authorize?: false`: the whole dashboard is already behind the
  organization membership gate, and these are non-sensitive roll-up numbers scoped to
  the tenant. Per-widget permission gating (hiding a tile a role can't drill into) is a
  UI concern layered on top, not enforced here.

  Resources that use Option-B archival keep archived rows visible to their primary read,
  so every count here filters `is_nil(archived_at)` to exclude archived records.
  """
  require Ash.Query

  alias Fleetms.FuelManagement.FuelEntry
  alias Fleetms.Inventory.Part
  alias Fleetms.Maintenance.ServiceReminder
  alias Fleetms.Maintenance.WorkOrder
  alias Fleetms.VehicleIssues.Issue
  alias Fleetms.VehicleIssues.IssuePriority
  alias Fleetms.VehicleManagement.Vehicle
  alias Fleetms.VehicleManagement.VehicleRenewal
  alias Fleetms.VehicleManagement.VehicleStatus

  @doc """
  Returns the dashboard summary for `scope`'s organization: vehicle counts by status,
  open/overdue issues, work orders in progress, and reminders/renewals coming due.
  """
  def summary(scope) do
    %{
      vehicle_status: vehicle_status_counts(scope),
      open_issues: open_issue_count(scope),
      overdue_issues: overdue_issue_count(scope),
      work_orders_in_progress: work_orders_by_status(scope, :in_progress),
      work_orders_open: work_orders_by_status(scope, :open),
      reminders_due: reminders_due_count(scope),
      renewals_due: renewals_due_count(scope)
    }
  end

  # --- vehicles ---

  # A map of every status to its count (statuses with no vehicles are 0), so the caller
  # can show the full breakdown without guessing which statuses exist.
  defp vehicle_status_counts(scope) do
    counts =
      Vehicle
      |> Ash.Query.select([:status])
      |> read(scope)
      |> Enum.frequencies_by(& &1.status)

    Map.merge(Map.from_keys(VehicleStatus.values(), 0), counts)
  end

  # --- issues ---

  defp open_issue_count(scope) do
    Issue
    |> Ash.Query.filter(status == :open and is_nil(archived_at))
    |> count(scope)
  end

  defp overdue_issue_count(scope) do
    today = Date.utc_today()

    Issue
    |> Ash.Query.filter(
      status == :open and is_nil(archived_at) and not is_nil(due_date) and due_date < ^today
    )
    |> count(scope)
  end

  # --- work orders ---

  defp work_orders_by_status(scope, status) do
    WorkOrder
    |> Ash.Query.filter(status == ^status and is_nil(archived_at))
    |> count(scope)
  end

  # --- reminders & renewals (their "due" state is a derived calculation) ---

  defp reminders_due_count(scope) do
    ServiceReminder
    |> Ash.Query.filter(is_nil(archived_at))
    |> Ash.Query.load(:due_status)
    |> read(scope)
    |> Enum.count(&(&1.due_status in [:due_soon, :overdue]))
  end

  defp renewals_due_count(scope) do
    VehicleRenewal
    |> Ash.Query.filter(is_nil(archived_at))
    |> Ash.Query.load(:status)
    |> read(scope)
    |> Enum.count(&(&1.status in ["Due Soon", "Overdue"]))
  end

  # --- chart series (monthly trends over the last `months` calendar months) ---

  @doc """
  Issues opened vs resolved per month, for a `months`-month window ending this month.
  Returns `%{categories: [labels], opened: [counts], resolved: [counts]}`.
  """
  def issues_trend(scope, months \\ 6) do
    buckets = month_buckets(months)
    since = window_start(buckets)

    opened =
      Issue
      |> Ash.Query.filter(is_nil(archived_at) and reported_at >= ^since)
      |> Ash.Query.select([:reported_at])
      |> read(scope)
      |> bucket(& &1.reported_at, buckets)

    resolved =
      Issue
      |> Ash.Query.filter(
        is_nil(archived_at) and not is_nil(resolved_at) and resolved_at >= ^since
      )
      |> Ash.Query.select([:resolved_at])
      |> read(scope)
      |> bucket(& &1.resolved_at, buckets)

    %{categories: Enum.map(buckets, &label/1), opened: opened, resolved: resolved}
  end

  @doc """
  Fuel spend per month in the organization's default currency (entries logged in another
  currency are left out, since currencies can't be summed). Returns
  `%{categories: [labels], values: [floats], currency: code}`.
  """
  def fuel_spend(scope, months \\ 6) do
    buckets = month_buckets(months)
    since = window_start(buckets)
    currency = scope.organization.currency

    by_bucket =
      FuelEntry
      |> Ash.Query.filter(is_nil(archived_at) and refueled_at >= ^since)
      |> Ash.Query.select([:refueled_at, :cost])
      |> read(scope)
      |> Enum.filter(fn e -> e.cost && to_string(e.cost.currency) == currency end)
      |> Enum.group_by(&year_month(&1.refueled_at), & &1.cost.amount)

    values =
      Enum.map(buckets, fn bucket ->
        by_bucket |> Map.get(bucket, []) |> sum_decimals() |> Decimal.to_float()
      end)

    %{categories: Enum.map(buckets, &label/1), values: values, currency: currency}
  end

  @doc """
  Maintenance spend per month — the parts + labour subtotals of work orders completed in
  each month, in the organization's default currency (line items in another currency are
  left out, since currencies can't be summed). Returns
  `%{categories: [labels], values: [floats], currency: code}`.
  """
  def maintenance_spend(scope, months \\ 6) do
    buckets = month_buckets(months)
    since = window_start(buckets)
    currency = scope.organization.currency

    by_bucket =
      WorkOrder
      |> Ash.Query.filter(
        is_nil(archived_at) and status == :completed and not is_nil(completed_at) and
          completed_at >= ^since
      )
      |> Ash.Query.load(work_order_service_tasks: [:work_order_service_task_parts, :labor_items])
      |> read(scope)
      |> Enum.group_by(&year_month(&1.completed_at), &work_order_spend(&1, currency))

    values =
      Enum.map(buckets, fn bucket ->
        by_bucket |> Map.get(bucket, []) |> sum_decimals() |> Decimal.to_float()
      end)

    %{categories: Enum.map(buckets, &label/1), values: values, currency: currency}
  end

  # Sum a work order's part + labour subtotals that are in `currency`, as a Decimal.
  defp work_order_spend(work_order, currency) do
    work_order.work_order_service_tasks
    |> Enum.flat_map(fn task ->
      task.work_order_service_task_parts ++ task.labor_items
    end)
    |> Enum.map(& &1.subtotal)
    |> Enum.filter(fn money -> money && to_string(money.currency) == currency end)
    |> Enum.map(& &1.amount)
    |> sum_decimals()
  end

  @doc """
  Open issues grouped by priority (in priority order). Returns
  `%{categories: [labels], values: [counts]}`.
  """
  def open_issues_by_priority(scope) do
    counts =
      Issue
      |> Ash.Query.filter(status == :open and is_nil(archived_at))
      |> Ash.Query.select([:priority])
      |> read(scope)
      |> Enum.frequencies_by(& &1.priority)

    priorities = IssuePriority.values()

    %{
      categories: Enum.map(priorities, &to_string/1),
      values: Enum.map(priorities, &Map.get(counts, &1, 0))
    }
  end

  # --- attention lists (things needing action, soonest first) ---

  @doc """
  Service reminders that are due soon or overdue, soonest due-date first, capped at
  `limit`. Each is a small map: vehicle, task, due-status and a due label.
  """
  def due_reminders(scope, limit \\ 6) do
    ServiceReminder
    |> Ash.Query.filter(is_nil(archived_at))
    |> Ash.Query.load([:due_status, :service_task_name, :vehicle_mileage, vehicle: [:name]])
    |> Ash.Query.sort(next_due_date: :asc)
    |> read(scope)
    |> Enum.filter(&(&1.due_status in [:due_soon, :overdue]))
    |> Enum.take(limit)
    |> Enum.map(fn r ->
      %{
        id: r.id,
        vehicle: r.vehicle && r.vehicle.name,
        task: r.service_task_name,
        status: r.due_status,
        due_date: r.next_due_date,
        due_mileage: r.next_due_mileage
      }
    end)
  end

  @doc """
  Vehicle renewals that are due soon or overdue, soonest first, capped at `limit`.
  """
  def due_renewals(scope, limit \\ 6) do
    VehicleRenewal
    |> Ash.Query.filter(is_nil(archived_at))
    |> Ash.Query.load([:status, vehicle: [:name], renewal_type: [:name]])
    |> Ash.Query.sort(due_date: :asc)
    |> read(scope)
    |> Enum.filter(&(&1.status in ["Due Soon", "Overdue"]))
    |> Enum.take(limit)
    |> Enum.map(fn r ->
      %{
        id: r.id,
        vehicle: r.vehicle && r.vehicle.name,
        type: r.renewal_type && r.renewal_type.name,
        status: r.status,
        due_date: r.due_date
      }
    end)
  end

  @doc "The most recently reported open issues, newest first, capped at `limit`."
  def recent_issues(scope, limit \\ 6) do
    Issue
    |> Ash.Query.filter(is_nil(archived_at))
    |> Ash.Query.load([:vehicle])
    |> Ash.Query.sort(reported_at: :desc)
    |> Ash.Query.limit(limit)
    |> read(scope)
    |> Enum.map(fn i ->
      %{
        id: i.id,
        number: i.issue_number,
        title: i.title,
        vehicle: i.vehicle && i.vehicle.name,
        priority: i.priority,
        status: i.status,
        reported_at: i.reported_at
      }
    end)
  end

  @doc """
  Tracked parts that are low or out of stock, capped at `limit`. `stock_status` is a
  derived calculation, so filtering happens after load.
  """
  def low_stock_parts(scope, limit \\ 6) do
    Part
    |> Ash.Query.filter(is_nil(archived_at) and track_inventory == true)
    |> Ash.Query.load([:stock_status, :total_stock])
    |> read(scope)
    |> Enum.filter(&(&1.stock_status in ["Low", "Out of stock"]))
    |> Enum.sort_by(&Decimal.to_float(&1.total_stock))
    |> Enum.take(limit)
    |> Enum.map(fn p ->
      %{
        id: p.id,
        part_number: p.part_number,
        name: p.name,
        status: p.stock_status,
        on_hand: p.total_stock,
        threshold: p.quantity_threshold
      }
    end)
  end

  # --- helpers ---

  defp count(query, scope),
    do:
      query |> scope_to_owner(scope) |> Ash.count!(tenant: scope.organization, authorize?: false)

  @doc """
  Getting-started progress for a new org: how many vehicles, issues and service
  reminders exist. The dashboard turns these into a dismissible checklist and
  hides it once all three are non-zero.
  """
  def onboarding(scope) do
    %{
      vehicles: count(Vehicle, scope),
      issues: count(Issue, scope),
      reminders: count(ServiceReminder, scope)
    }
  end

  defp read(query, scope),
    do: query |> scope_to_owner(scope) |> Ash.read!(tenant: scope.organization, authorize?: false)

  # The dashboard counts run with `authorize?: false`, which is fine when the org
  # (schema) is the boundary. In the shared individuals pool it is NOT — each
  # client owns only their rows — so scope the queries to the relevant client's
  # `owner_id`, otherwise a client would see pool-wide totals. Applies only to
  # owner-scoped resources (shared catalogs like parts are left alone).
  defp scope_to_owner(query, scope) do
    q = Ash.Query.new(query)

    with owner when not is_nil(owner) <- Fleetms.Individuals.acting_owner_id(scope),
         true <- not is_nil(Ash.Resource.Info.attribute(q.resource, :owner_id)) do
      Ash.Query.filter(q, owner_id == ^owner)
    else
      _ -> query
    end
  end

  # The last `n` months as `{year, month}` tuples, oldest first, ending this month.
  defp month_buckets(n) do
    today = Date.utc_today()

    for i <- (n - 1)..0//-1 do
      d = Date.shift(today, month: -i)
      {d.year, d.month}
    end
  end

  # Midnight UTC on the first day of the earliest bucket.
  defp window_start([{year, month} | _]) do
    {:ok, dt} = DateTime.new(Date.new!(year, month, 1), ~T[00:00:00], "Etc/UTC")
    dt
  end

  defp bucket(rows, date_fun, buckets) do
    counts = Enum.frequencies_by(rows, fn row -> year_month(date_fun.(row)) end)
    Enum.map(buckets, &Map.get(counts, &1, 0))
  end

  defp year_month(%DateTime{year: year, month: month}), do: {year, month}

  defp label({year, month}), do: Calendar.strftime(Date.new!(year, month, 1), "%b")

  defp sum_decimals(decimals), do: Enum.reduce(decimals, Decimal.new(0), &Decimal.add/2)
end
