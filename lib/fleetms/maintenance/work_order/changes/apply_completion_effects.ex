defmodule Fleetms.Maintenance.WorkOrder.Changes.ApplyCompletionEffects do
  @moduledoc """
  The side-effects of completing a work order, applied in the completion
  transaction so they're all-or-nothing with the status change:

    * **Consume stock** — each part line flagged `consume_stock?` (and pinned to a
      location) is drawn down from that `InventoryLocation` via the `PartStock.adjust`
      seam. If a location isn't stocked, or hasn't enough on hand, completion fails
      and everything rolls back (you can't consume stock you don't have).
    * **Reset reminders** — for each service task on the order, the matching service
      reminder for this vehicle+task (if any) is re-baselined to now, so its next-due
      point moves forward.
    * **Resolve issues** — any still-open issues linked to the order are resolved.

  Runs `after_action`, unauthorized (an internal cascade of the already-authorized
  `complete` action). No Reactor: every step is a Postgres write on the same repo,
  so the surrounding transaction already gives atomic all-or-nothing — Reactor's
  compensations are for non-transactional/external steps, which this has none of.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Fleetms.Inventory
  alias Fleetms.Maintenance
  alias Fleetms.VehicleIssues

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, work_order ->
      opts = [tenant: context.tenant, actor: context.actor, authorize?: false]

      work_order =
        Ash.load!(
          work_order,
          [
            :issues,
            work_order_service_tasks: [:service_task_name, work_order_service_task_parts: [:part]]
          ],
          opts
        )

      case consume_stock(work_order, opts) do
        :ok ->
          snapshot_names(work_order, opts)
          reset_reminders(work_order, opts)
          resolve_issues(work_order, opts)
          {:ok, work_order}

        {:error, _} = error ->
          error
      end
    end)
  end

  # Freeze the part/service-task names onto each line so a later catalogue rename can't
  # rewrite what a finished work order says was done.
  defp snapshot_names(work_order, opts) do
    Enum.each(work_order.work_order_service_tasks, fn task ->
      task
      |> Ash.Changeset.for_update(
        :freeze_snapshot,
        %{service_task_name: task.service_task_name},
        opts
      )
      |> Ash.update!(opts)

      Enum.each(task.work_order_service_task_parts, fn line ->
        line
        |> Ash.Changeset.for_update(
          :freeze_snapshot,
          %{
            part_name: line.part && line.part.name,
            part_number: line.part && line.part.part_number
          },
          opts
        )
        |> Ash.update!(opts)
      end)
    end)
  end

  defp consume_stock(work_order, opts) do
    work_order.work_order_service_tasks
    |> Enum.flat_map(& &1.work_order_service_task_parts)
    |> Enum.filter(&(&1.consume_stock? and &1.inventory_location_id))
    |> Enum.reduce_while(:ok, fn line, :ok ->
      case consume_line(line, opts) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp consume_line(line, opts) do
    case find_stock(line.part_id, line.inventory_location_id, opts) do
      nil ->
        {:error, "A part on this work order is not stocked at its chosen location."}

      stock ->
        case Inventory.adjust_part_stock(stock, %{delta: Decimal.negate(line.quantity)}, opts) do
          {:ok, _updated} -> :ok
          {:error, _} -> {:error, "Not enough of a part on hand to consume from its location."}
        end
    end
  end

  defp find_stock(part_id, location_id, opts) do
    Inventory.PartStock
    |> Ash.Query.filter(part_id == ^part_id and inventory_location_id == ^location_id)
    |> Ash.read_one!(opts)
  end

  defp reset_reminders(work_order, opts) do
    task_ids = Enum.map(work_order.work_order_service_tasks, & &1.service_task_id)

    Maintenance.ServiceReminder
    |> Ash.Query.filter(vehicle_id == ^work_order.vehicle_id and service_task_id in ^task_ids)
    |> Ash.read!(opts)
    |> Enum.each(&Maintenance.reset_service_reminder!(&1, opts))
  end

  # Resolve the still-open issues this work order was raised to address. It's the
  # last completion step, so its notification's `after_transaction` hook firing
  # inside the completion transaction is intentional (nothing rolls back after it) —
  # silence Ash's warning about that nesting for just these calls.
  defp resolve_issues(work_order, opts) do
    opts = Keyword.put(opts, :context, %{warn_on_transaction_hooks?: false})

    work_order.issues
    |> Enum.filter(&(&1.status == :open))
    |> Enum.each(&VehicleIssues.resolve_issue!(&1, opts))
  end
end
