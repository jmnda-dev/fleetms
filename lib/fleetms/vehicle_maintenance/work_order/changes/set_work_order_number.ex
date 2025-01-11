defmodule Fleetms.VehicleMaintenance.WorkOrder.Changes.SetWorkOrderNumber do
  use Ash.Resource.Change

  def change(changeset, _opts, %Ash.Resource.Change.Context{actor: actor, tenant: tenant}) do
    # TODO: Be sure to verify that the `lock` on the sequence does actually work and the record can not be updated during this transaction.
    sequence =
      Fleetms.Common.Sequence.get_work_order_resource_sequence!(actor: actor, tenant: tenant)

    changeset
    |> Ash.Changeset.force_change_attribute(:work_order_number, sequence.current_count)
    |> Ash.Changeset.after_action(fn _changeset, created_work_order ->
      Fleetms.Common.Sequence.increment!(sequence, actor: actor, tenant: tenant)
      {:ok, created_work_order}
    end)
  end
end
