defmodule Fleetms.Service.Calculations.WorkOrderServiceTaskVehicleReminder do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    # I load vehicle_mileage here because I need it I pass service reminders to the function
    # for resetting the reminder when completing the work order.
    [service_task: [vehicle_service_reminder: [:vehicle_mileage]]]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      record.service_task.vehicle_service_reminder
    end)
  end
end
