defmodule Fleetms.Maintenance.LaborTest do
  use Fleetms.DataCase

  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance

  setup :shared_org

  defp work_order_with_labor(scope, labor_items) do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)

    wo =
      Maintenance.create_work_order!(
        %{
          vehicle_id: vehicle.id,
          work_order_service_tasks: [%{service_task_id: task.id, labor_items: labor_items}]
        },
        scope: scope
      )

    Maintenance.get_work_order!(wo.id,
      scope: scope,
      load: [work_order_service_tasks: [:labor_items]]
    )
  end

  test "technician labour subtotal is hours × rate", %{owner: owner, scope: scope} do
    wo =
      work_order_with_labor(scope, [
        %{
          labor_type: :technician,
          technician_id: owner.id,
          hours: Decimal.new("2.5"),
          hourly_rate: Money.new(:USD, "40.00")
        }
      ])

    [task] = wo.work_order_service_tasks
    [labor] = task.labor_items

    assert labor.labor_type == :technician
    assert Money.equal?(labor.subtotal, Money.new(:USD, "100.00"))
  end

  test "vendor labour subtotal is the flat cost", %{scope: scope} do
    vendor = vendor_fixture(scope, %{name: "Ace Body Shop"})

    wo =
      work_order_with_labor(scope, [
        %{labor_type: :vendor, vendor_id: vendor.id, flat_cost: Money.new(:USD, "250.00")}
      ])

    [task] = wo.work_order_service_tasks
    [labor] = task.labor_items

    assert labor.labor_type == :vendor
    assert Money.equal?(labor.subtotal, Money.new(:USD, "250.00"))
  end

  test "technician labour requires a technician", %{scope: scope} do
    assert_raise Ash.Error.Invalid, fn ->
      work_order_with_labor(scope, [
        %{labor_type: :technician, hours: Decimal.new("1"), hourly_rate: Money.new(:USD, "40.00")}
      ])
    end
  end

  test "vendor labour requires a vendor", %{scope: scope} do
    assert_raise Ash.Error.Invalid, fn ->
      work_order_with_labor(scope, [%{labor_type: :vendor, flat_cost: Money.new(:USD, "250.00")}])
    end
  end

  test "cost breakdown separates parts, technician and vendor labour and totals them", %{
    owner: owner,
    scope: scope
  } do
    vendor = vendor_fixture(scope)

    wo =
      work_order_with_labor(scope, [
        %{
          labor_type: :technician,
          technician_id: owner.id,
          hours: Decimal.new("2"),
          hourly_rate: Money.new(:USD, "50.00")
        },
        %{labor_type: :vendor, vendor_id: vendor.id, flat_cost: Money.new(:USD, "75.00")}
      ])

    breakdown = Maintenance.Costs.breakdown(wo, scope: scope)

    assert [technician] = breakdown.technician_labor
    assert Money.equal?(technician, Money.new(:USD, "100.00"))
    assert [vendor_total] = breakdown.vendor_labor
    assert Money.equal?(vendor_total, Money.new(:USD, "75.00"))
    assert [total] = breakdown.total
    assert Money.equal?(total, Money.new(:USD, "175.00"))
  end
end
