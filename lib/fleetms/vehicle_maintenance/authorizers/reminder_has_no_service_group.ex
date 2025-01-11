defmodule Fleetms.VehicleMaintenance.Authorizers.ReminderHasNoServiceGroup do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_) do
    "Ensure the ServiceReminder does not belong to a ServiceGroup"
  end

  @impl true
  def match?(_actor, %Ash.Policy.Authorizer{changeset: changeset} = _context, _options) do
    id = Ash.Changeset.get_attribute(changeset, :service_group_schedule_id)
    has_no_service_group?(id)
  end

  defp has_no_service_group?(nil), do: true
  defp has_no_service_group?(_id), do: false
end
