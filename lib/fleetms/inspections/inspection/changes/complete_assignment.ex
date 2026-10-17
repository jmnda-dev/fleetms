defmodule Fleetms.Inspections.Inspection.Changes.CompleteAssignment do
  @moduledoc """
  After an inspection is submitted, close the matching open scheduled assignment
  (same vehicle + form), if there is one.

  Runs in `after_transaction` so it sees the committed inspection (with its
  denormalized `inspection_form_id`) and runs outside the submit transaction; it is
  best-effort, so an unscheduled submission or a matching failure never affects the
  submit itself. See `Fleetms.Inspections.ScheduleRunner`.
  """
  use Ash.Resource.Change

  alias Fleetms.Inspections.{Inspection, ScheduleRunner}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, inspection} = result ->
        tenant = Ash.ToTenant.to_tenant(context.tenant, Inspection)
        ScheduleRunner.complete_matching(inspection, tenant)
        result

      _changeset, result ->
        result
    end)
  end
end
