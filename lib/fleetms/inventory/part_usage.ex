defmodule Fleetms.Inventory.PartUsage do
  @moduledoc """
  A part's consumption history: every work-order line that used it, newest first.

  Reads the work-order part lines (`WorkOrderServiceTaskPart`) for a part through
  the caller's scope, loading each line's work order for its number and date.
  Read-only and tenant-scoped; nothing is stored.
  """
  require Ash.Query

  alias Fleetms.Maintenance.WorkOrderServiceTaskPart

  @type usage :: %{
          quantity: Decimal.t(),
          date: DateTime.t() | nil,
          work_order_id: String.t() | nil,
          work_order_number: integer() | nil
        }

  @spec for_part(Fleetms.Scope.t(), String.t()) :: [usage()]
  def for_part(scope, part_id) do
    WorkOrderServiceTaskPart
    |> Ash.Query.filter(part_id == ^part_id)
    |> Ash.Query.load(work_order_service_task: [work_order: [:work_order_number, :issued_at]])
    |> Ash.read!(scope: scope)
    |> Enum.map(fn line ->
      wo = line.work_order_service_task && line.work_order_service_task.work_order

      %{
        quantity: line.quantity,
        date: wo && wo.issued_at,
        work_order_id: wo && wo.id,
        work_order_number: wo && wo.work_order_number
      }
    end)
    |> Enum.sort_by(&sort_key(&1.date), :desc)
  end

  # Newest first; lines whose work order has no date sink to the bottom.
  defp sort_key(nil), do: 0
  defp sort_key(%DateTime{} = dt), do: DateTime.to_unix(dt)

  @doc "Total quantity of the part consumed across all work orders."
  @spec total(Fleetms.Scope.t(), String.t()) :: Decimal.t()
  def total(scope, part_id) do
    scope
    |> for_part(part_id)
    |> Enum.reduce(Decimal.new(0), fn u, acc -> Decimal.add(acc, u.quantity || Decimal.new(0)) end)
  end
end
