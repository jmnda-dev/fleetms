defmodule Fleetms.VehicleMaintenance.Calculations.WorkOrderServiceTaskVehicleReminder do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    # I load vehicle_mileage here because I need it I pass service reminders to the function
    # for resetting the reminder when completing the work order.
    # [service_task: [vehicle_service_reminder: [:vehicle_mileage]]]
    [:vehicle_service_reminders]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # record =
      IO.inspect(record)
      if is_list(record.vehicle_service_reminders) do
        hd(record.vehicle_service_reminders)
      else
        nil
      end
    end)
  end
end
