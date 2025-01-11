defmodule Fleetms.VehicleMaintenance.Authorizers.ReminderBelongsToServiceGroupSchedule do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_) do
    "Ensure the ServiceReminder belongs to Service Group Schedule"
  end

  @impl true
  def match?(_actor, %Ash.Policy.Authorizer{changeset: changeset} = _context, _options) do
    id = Ash.Changeset.get_attribute(changeset, :service_group_id)
    belongs_to_service_group_schedule?(id)
  end

  defp belongs_to_service_group_schedule?(nil), do: false
  defp belongs_to_service_group_schedule?(_id), do: true
end
