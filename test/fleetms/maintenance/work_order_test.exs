defmodule Fleetms.Maintenance.WorkOrderTest do
  use Fleetms.DataCase

  import Fleetms.MaintenanceFixtures
  import Fleetms.InventoryFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance

  setup :shared_org

  describe "create" do
    test "assigns a sequential number, opens the order, and records the actor", %{
      owner: owner,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)

      wo =
        Maintenance.create_work_order!(
          %{vehicle_id: vehicle.id, description: "Annual service"},
          scope: scope
        )

      assert wo.status == :open
      assert is_integer(wo.work_order_number)
      assert wo.issued_by_id == owner.id
    end

    test "numbers increase per order", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      a = work_order_fixture(scope, %{vehicle_id: vehicle.id})
      b = work_order_fixture(scope, %{vehicle_id: vehicle.id})

      assert b.work_order_number == a.work_order_number + 1
    end

    test "creates nested service tasks with parts and freezes each subtotal", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      task = service_task_fixture(scope, %{name: "Oil change"})
      part = part_fixture(scope, %{name: "Oil filter"})

      wo =
        Maintenance.create_work_order!(
          %{
            vehicle_id: vehicle.id,
            work_order_service_tasks: [
              %{
                service_task_id: task.id,
                work_order_service_task_parts: [
                  %{
                    part_id: part.id,
                    quantity: Decimal.new("3"),
                    unit_cost: Money.new(:USD, "10.00")
                  }
                ]
              }
            ]
          },
          scope: scope
        )

      wo =
        Maintenance.get_work_order!(wo.id,
          scope: scope,
          load: [work_order_service_tasks: [:work_order_service_task_parts]]
        )

      assert [line] = wo.work_order_service_tasks
      assert [part_line] = line.work_order_service_task_parts
      assert Money.equal?(part_line.subtotal, Money.new(:USD, "30.00"))
    end
  end

  describe "lifecycle transitions" do
    test "start → complete → reopen move status and stamp timestamps", %{scope: scope} do
      wo = work_order_fixture(scope)

      wo = Maintenance.start_work_order!(wo, scope: scope)
      assert wo.status == :in_progress
      assert wo.started_at

      wo = Maintenance.complete_work_order!(wo, scope: scope)
      assert wo.status == :completed
      assert wo.completed_at

      wo = Maintenance.reopen_work_order!(wo, scope: scope)
      assert wo.status == :in_progress
      refute wo.completed_at
    end

    test "cannot reopen an order that was never completed", %{scope: scope} do
      wo = work_order_fixture(scope)

      assert_raise Ash.Error.Invalid, fn ->
        Maintenance.reopen_work_order!(wo, scope: scope)
      end
    end
  end

  describe "costs" do
    test "parts_total sums subtotals per currency", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      task = service_task_fixture(scope)
      part = part_fixture(scope)

      wo =
        Maintenance.create_work_order!(
          %{
            vehicle_id: vehicle.id,
            work_order_service_tasks: [
              %{
                service_task_id: task.id,
                work_order_service_task_parts: [
                  %{
                    part_id: part.id,
                    quantity: Decimal.new("2"),
                    unit_cost: Money.new(:USD, "10.00")
                  },
                  %{
                    part_id: part.id,
                    quantity: Decimal.new("1"),
                    unit_cost: Money.new(:USD, "5.50")
                  }
                ]
              }
            ]
          },
          scope: scope
        )

      assert [total] = Fleetms.Maintenance.Costs.parts_total(wo, scope: scope)
      assert Money.equal?(total, Money.new(:USD, "25.50"))
    end
  end

  describe "list" do
    test "searches by vehicle name", %{scope: scope} do
      zephyr = vehicle_fixture(scope, %{name: "Zephyr Hauler"})
      other = vehicle_fixture(scope, %{name: "Boxcar Runner"})
      work_order_fixture(scope, %{vehicle_id: zephyr.id})
      work_order_fixture(scope, %{vehicle_id: other.id})

      page = Maintenance.list_work_orders!(%{search_query: "zephyr"}, scope: scope)

      assert Enum.map(page.results, & &1.vehicle.name) == ["Zephyr Hauler"]
    end
  end
end
