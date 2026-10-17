defmodule Fleetms.Maintenance.Costs do
  @moduledoc """
  Derived cost totals for a work order, computed in Elixir over its line items.

  Money is kept per-currency rather than summed with a SQL aggregate: a work
  order's lines can each carry their own currency, and amounts in different
  currencies don't add together. So every total is a list of `Money` — one entry
  per currency present — mirroring how `Fleetms.FuelManagement.Economy` handles
  spend. Keeping this in Elixir also keeps `AshMoney.Types.Money` out of `:ash`'s
  `known_types`, which must stay disabled (see the ash_money notes).

  A "total" is built from three streams of subtotals: parts, and labour split into
  technician (internal) and vendor (outsourced). `breakdown/2` returns all of them
  plus the grand total in one loaded pass.
  """
  alias Fleetms.Maintenance

  @type totals :: %{
          parts: [Money.t()],
          technician_labor: [Money.t()],
          vendor_labor: [Money.t()],
          labor: [Money.t()],
          total: [Money.t()]
        }

  @load [work_order_service_tasks: [:work_order_service_task_parts, :labor_items]]

  @doc """
  Total parts cost for a work order, as a list of `Money` grouped by currency.

  Pass a loaded work order or an id. `opts` is forwarded to the read (pass
  `scope:`). Lines with no subtotal (no unit cost) contribute nothing.
  """
  @spec parts_total(Maintenance.WorkOrder.t() | Ecto.UUID.t(), keyword()) :: [Money.t()]
  def parts_total(work_order_or_id, opts \\ []), do: breakdown(work_order_or_id, opts).parts

  @doc """
  Full cost breakdown for a work order: parts, technician labour, vendor labour,
  combined labour, and the grand total — each a per-currency list of `Money`.
  """
  @spec breakdown(Maintenance.WorkOrder.t() | Ecto.UUID.t(), keyword()) :: totals()
  def breakdown(work_order_or_id, opts \\ [])

  def breakdown(%Maintenance.WorkOrder{} = work_order, opts) do
    tasks = Ash.load!(work_order, @load, opts).work_order_service_tasks

    parts = tasks |> Enum.flat_map(& &1.work_order_service_task_parts) |> collect_subtotals()
    labor = tasks |> Enum.flat_map(& &1.labor_items)

    technician = labor |> Enum.filter(&(&1.labor_type == :technician)) |> collect_subtotals()
    vendor = labor |> Enum.filter(&(&1.labor_type == :vendor)) |> collect_subtotals()

    %{
      parts: parts,
      technician_labor: technician,
      vendor_labor: vendor,
      labor: sum_by_currency(technician ++ vendor),
      total: sum_by_currency(parts ++ technician ++ vendor)
    }
  end

  def breakdown(id, opts) when is_binary(id) do
    Maintenance.get_work_order!(id, opts) |> breakdown(opts)
  end

  # Pull non-nil subtotals off a set of lines and collapse them per currency.
  defp collect_subtotals(lines) do
    lines |> Enum.map(& &1.subtotal) |> Enum.reject(&is_nil/1) |> sum_by_currency()
  end

  # Sum amounts within each currency; different currencies stay separate.
  defp sum_by_currency(monies) do
    monies
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {_currency, [first | rest]} ->
      Enum.reduce(rest, first, &Money.add!(&2, &1))
    end)
  end
end
