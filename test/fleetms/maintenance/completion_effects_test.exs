defmodule Fleetms.Maintenance.CompletionEffectsTest do
  use Fleetms.DataCase

  require Ash.Query

  import Fleetms.MaintenanceFixtures
  import Fleetms.InventoryFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Inventory
  alias Fleetms.Maintenance
  alias Fleetms.VehicleManagement

  setup :shared_org

  # `location` may be nil — a part with no location is one bought for the job, not
  # drawn from stock. Choosing a location is what marks the line for consumption.
  defp work_order_with_part(scope, vehicle, task, part, location, quantity) do
    Maintenance.create_work_order!(
      %{
        vehicle_id: vehicle.id,
        work_order_service_tasks: [
          %{
            service_task_id: task.id,
            work_order_service_task_parts: [
              %{
                part_id: part.id,
                inventory_location_id: location && location.id,
                quantity: quantity,
                unit_cost: Money.new(:USD, "10.00")
              }
            ]
          }
        ]
      },
      scope: scope
    )
  end

  defp stock_qty(scope, part, location) do
    Inventory.PartStock
    |> Ash.Query.filter(part_id == ^part.id and inventory_location_id == ^location.id)
    |> Ash.read_one!(scope: scope)
    |> Map.get(:quantity)
  end

  test "completing draws a part with a location down from that stock", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)
    part = part_fixture(scope)
    location = inventory_location_fixture(scope)
    part_stock_fixture(scope, part, location, Decimal.new("10"))

    # Choosing a location is enough — the line is marked for consumption from it.
    wo = work_order_with_part(scope, vehicle, task, part, location, Decimal.new("3"))
    Maintenance.complete_work_order!(wo, scope: scope)

    assert Decimal.equal?(stock_qty(scope, part, location), Decimal.new("7"))
  end

  test "a part with no location leaves stock untouched", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)
    part = part_fixture(scope)
    location = inventory_location_fixture(scope)
    part_stock_fixture(scope, part, location, Decimal.new("10"))

    wo = work_order_with_part(scope, vehicle, task, part, nil, Decimal.new("3"))
    Maintenance.complete_work_order!(wo, scope: scope)

    assert Decimal.equal?(stock_qty(scope, part, location), Decimal.new("10"))
  end

  test "completing resets the matching service reminder", %{scope: scope} do
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
    task = service_task_fixture(scope)

    reminder =
      service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

    VehicleManagement.update_vehicle!(vehicle, %{mileage: Decimal.new("16000")}, scope: scope)

    assert Maintenance.get_service_reminder!(reminder.id, scope: scope).due_status == :overdue

    wo =
      Maintenance.create_work_order!(
        %{vehicle_id: vehicle.id, work_order_service_tasks: [%{service_task_id: task.id}]},
        scope: scope
      )

    Maintenance.complete_work_order!(wo, scope: scope)

    reminder = Maintenance.get_service_reminder!(reminder.id, scope: scope)
    assert Decimal.equal?(reminder.last_completed_mileage, Decimal.new("16000"))
    assert Decimal.equal?(reminder.next_due_mileage, Decimal.new("21000"))
    assert reminder.due_status == :upcoming
  end

  defp load_lines(scope, id) do
    Maintenance.get_work_order!(id,
      scope: scope,
      load: [work_order_service_tasks: [:service_task_name, :work_order_service_task_parts]]
    )
  end

  test "completing freezes the part and service-task names against a later rename",
       %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope, %{name: "Oil change"})
    part = part_fixture(scope, %{name: "Oil filter", part_number: "OF-1"})

    wo = work_order_with_part(scope, vehicle, task, part, nil, Decimal.new("1"))
    Maintenance.complete_work_order!(wo, scope: scope)

    # Rename the catalogue records after completion.
    Inventory.update_part!(part, %{name: "Oil filter v2", part_number: "OF-2"}, scope: scope)
    Maintenance.update_service_task!(task, %{name: "Oil change v2"}, scope: scope)

    [t] = load_lines(scope, wo.id).work_order_service_tasks
    assert t.service_task_name_snapshot == "Oil change"
    [p] = t.work_order_service_task_parts
    assert p.part_name == "Oil filter"
    assert p.part_number == "OF-1"
  end

  test "an open work order carries no snapshot and shows the live name", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope, %{name: "Brake job"})
    part = part_fixture(scope, %{name: "Brake pad"})

    wo = work_order_with_part(scope, vehicle, task, part, nil, Decimal.new("1"))

    [t] = load_lines(scope, wo.id).work_order_service_tasks
    assert is_nil(t.service_task_name_snapshot)
    assert t.service_task_name == "Brake job"
    [p] = t.work_order_service_task_parts
    assert is_nil(p.part_name)
  end

  test "insufficient stock fails completion and rolls everything back", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)
    part = part_fixture(scope)
    location = inventory_location_fixture(scope)
    part_stock_fixture(scope, part, location, Decimal.new("2"))

    wo = work_order_with_part(scope, vehicle, task, part, location, Decimal.new("5"))

    assert {:error, _} = Maintenance.complete_work_order(wo, scope: scope)

    # nothing changed: the order didn't complete and stock is intact
    assert Maintenance.get_work_order!(wo.id, scope: scope).status == :open
    assert Decimal.equal?(stock_qty(scope, part, location), Decimal.new("2"))
  end
end
