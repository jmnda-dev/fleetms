defmodule Fleetms.MaintenanceFixtures do
  @moduledoc "Test fixtures for the maintenance domain."
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance

  def service_task_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Service Task #{System.unique_integer([:positive])}"})
    Maintenance.create_service_task!(attrs, scope: scope)
  end

  def vendor_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Vendor #{System.unique_integer([:positive])}"})
    Maintenance.create_vendor!(attrs, scope: scope)
  end

  @doc """
  Creates a service group. Pass `:vehicle_ids` and `:schedules` (a list of maps
  like `%{service_task_id: id, mileage_interval: ...}`) to fan out reminders.
  """
  def service_group_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Group #{System.unique_integer([:positive])}"})
    Maintenance.create_service_group!(attrs, scope: scope)
  end

  @doc """
  Creates a service reminder. Pass `:vehicle_id` and `:service_task_id` to reuse
  existing records, and interval attrs (defaults to a 5,000-mile interval).
  """
  def service_reminder_fixture(scope, vehicle, service_task, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        vehicle_id: vehicle.id,
        service_task_id: service_task.id,
        mileage_interval: Decimal.new("5000")
      })

    Maintenance.create_service_reminder!(attrs, scope: scope)
  end

  @doc """
  Creates a work order for a vehicle. Pass `:vehicle_id` to reuse a vehicle, and
  `:work_order_service_tasks` (a list of nested-line maps) to add line items.
  """
  def work_order_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        vehicle_id: attrs[:vehicle_id] || vehicle_fixture(scope).id
      })

    Maintenance.create_work_order!(attrs, scope: scope)
  end
end
