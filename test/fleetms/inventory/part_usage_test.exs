defmodule Fleetms.Inventory.PartUsageTest do
  @moduledoc "A part's usage history is gathered from the work-order lines that consumed it."
  use Fleetms.DataCase, async: true

  import Fleetms.InventoryFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Inventory.PartUsage

  setup :shared_org

  test "lists the work-order lines that used the part and totals the quantity", %{scope: scope} do
    part = part_fixture(scope)
    other = part_fixture(scope)
    task = service_task_fixture(scope)
    vehicle = vehicle_fixture(scope)

    work_order_fixture(scope, %{
      vehicle_id: vehicle.id,
      work_order_service_tasks: [
        %{
          service_task_id: task.id,
          work_order_service_task_parts: [
            %{part_id: part.id, quantity: Decimal.new("3"), unit_cost: Money.new(:USD, "10.00")},
            %{part_id: other.id, quantity: Decimal.new("9"), unit_cost: Money.new(:USD, "5.00")}
          ]
        }
      ]
    })

    usage = PartUsage.for_part(scope, part.id)

    assert length(usage) == 1
    assert [%{quantity: qty, work_order_number: n}] = usage
    assert Decimal.equal?(qty, Decimal.new("3"))
    assert is_integer(n)

    assert Decimal.equal?(PartUsage.total(scope, part.id), Decimal.new("3"))
  end

  test "a part never used has empty usage", %{scope: scope} do
    part = part_fixture(scope)
    assert PartUsage.for_part(scope, part.id) == []
    assert Decimal.equal?(PartUsage.total(scope, part.id), Decimal.new("0"))
  end
end
