defmodule Fleetms.VehicleMaintenance.Calculations.SingleServiceTaskVehicleReminder do
  use Ash.Resource.Calculation

  require Ash.Query

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn
      %{service_reminders: []} = _record ->
        nil

      %{service_reminders: service_reminders} = _record ->
        # the service reminders list will only contain one service reminder, because the service reminder query filter we
        # have applied in the action where `:service_reminders` relationship is being loaded ensures one result is returned.
        # and the fact that a service reminder is unique by vehicle and service task.
        hd(service_reminders)
    end)
  end
end
