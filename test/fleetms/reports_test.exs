defmodule Fleetms.ReportsTest do
  @moduledoc """
  The maintenance & cost report: rows per work order with default-currency costs, a
  summary, and the date/vehicle/status filters.
  """
  use Fleetms.DataCase, async: true

  import Fleetms.InventoryFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Reports

  setup :shared_org

  # A work order for `vehicle` with one task carrying one part (in the org's default
  # currency, ZMW) at `unit_cost` × `qty`.
  defp work_order_with_cost(scope, vehicle, task, unit_cost, qty) do
    Maintenance.create_work_order!(
      %{
        vehicle_id: vehicle.id,
        work_order_service_tasks: [
          %{
            service_task_id: task.id,
            work_order_service_task_parts: [
              %{
                part_id: part_fixture(scope).id,
                quantity: qty,
                unit_cost: Money.new(:ZMW, unit_cost)
              }
            ]
          }
        ]
      },
      scope: scope
    )
  end

  test "rows carry per-work-order cost and the summary totals them", %{scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Hauler"})
    task = service_task_fixture(scope)
    work_order_with_cost(scope, vehicle, task, "10.00", Decimal.new("2"))
    work_order_with_cost(scope, vehicle, task, "5.00", Decimal.new("1"))

    report = Reports.maintenance_report(scope, %{})

    assert report.summary.count == 2
    assert report.currency == "ZMW"
    # 2×10 + 1×5 = 25 in parts, no labour.
    assert Decimal.equal?(report.summary.parts, Decimal.new("25.00"))
    assert Decimal.equal?(report.summary.total, Decimal.new("25.00"))
    assert [%{vehicle: "Hauler", parts: _} | _] = report.rows
  end

  test "a part in another currency is left out of the totals", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)

    Maintenance.create_work_order!(
      %{
        vehicle_id: vehicle.id,
        work_order_service_tasks: [
          %{
            service_task_id: task.id,
            work_order_service_task_parts: [
              %{
                part_id: part_fixture(scope).id,
                quantity: Decimal.new("1"),
                unit_cost: Money.new(:USD, "40.00")
              }
            ]
          }
        ]
      },
      scope: scope
    )

    report = Reports.maintenance_report(scope, %{})
    assert report.summary.count == 1
    assert Decimal.equal?(report.summary.total, Decimal.new("0"))
  end

  test "filters by vehicle and status", %{scope: scope} do
    task = service_task_fixture(scope)
    keep = vehicle_fixture(scope, %{name: "Keep"})
    drop = vehicle_fixture(scope, %{name: "Drop"})
    work_order_with_cost(scope, keep, task, "10.00", Decimal.new("1"))
    work_order_with_cost(scope, drop, task, "10.00", Decimal.new("1"))

    by_vehicle = Reports.maintenance_report(scope, %{"vehicle_id" => keep.id})
    assert by_vehicle.summary.count == 1
    assert [%{vehicle: "Keep"}] = by_vehicle.rows

    # Nothing is completed, so filtering to completed yields none.
    completed = Reports.maintenance_report(scope, %{"status" => "completed"})
    assert completed.summary.count == 0
  end

  test "the date range excludes work orders outside it", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)
    work_order_with_cost(scope, vehicle, task, "10.00", Decimal.new("1"))

    # A window entirely in the past excludes today's work order.
    past = %{"from" => "2020-01-01", "to" => "2020-12-31"}
    assert Reports.maintenance_report(scope, past).summary.count == 0
  end

  describe "cost of ownership" do
    test "totals maintenance, fuel, expenses and distance per vehicle", %{scope: scope} do
      import Fleetms.FuelFixtures

      vehicle = vehicle_fixture(scope, %{name: "Digger"})
      task = service_task_fixture(scope)

      # Completed work order → 2 × 10.00 ZMW maintenance.
      wo = work_order_with_cost(scope, vehicle, task, "10.00", Decimal.new("2"))
      Maintenance.complete_work_order!(wo, scope: scope)

      # Two fuel fills in ZMW, odometers 1000 → 1500 (distance 500).
      fuel_entry_fixture(scope, %{
        vehicle_id: vehicle.id,
        cost: Money.new(:ZMW, "80.00"),
        odometer: Decimal.new("1000")
      })

      fuel_entry_fixture(scope, %{
        vehicle_id: vehicle.id,
        cost: Money.new(:ZMW, "120.00"),
        odometer: Decimal.new("1500")
      })

      # A 30.00 ZMW expense on the same vehicle.
      Fleetms.Expenses.create_expense!(
        %{
          vehicle_id: vehicle.id,
          expense_date: Date.utc_today(),
          category: :insurance,
          amount: Money.new(:ZMW, "30.00")
        },
        scope: scope
      )

      report = Reports.cost_of_ownership_report(scope, %{})

      assert [row] = report.rows
      assert row.vehicle == "Digger"
      assert Decimal.equal?(row.maintenance, Decimal.new("20.00"))
      assert Decimal.equal?(row.fuel, Decimal.new("200.00"))
      assert Decimal.equal?(row.expenses, Decimal.new("30.00"))
      assert Decimal.equal?(row.total, Decimal.new("250.00"))
      assert Decimal.equal?(row.distance, Decimal.new("500"))
      assert Decimal.equal?(report.summary.total, Decimal.new("250.00"))
      assert Decimal.equal?(report.summary.expenses, Decimal.new("30.00"))
    end

    test "a single fuel reading yields no distance", %{scope: scope} do
      import Fleetms.FuelFixtures

      vehicle = vehicle_fixture(scope)

      fuel_entry_fixture(scope, %{
        vehicle_id: vehicle.id,
        cost: Money.new(:ZMW, "50.00"),
        odometer: Decimal.new("2000")
      })

      assert [row] = Reports.cost_of_ownership_report(scope, %{}).rows
      assert row.distance == nil
      assert Decimal.equal?(row.fuel, Decimal.new("50.00"))
    end

    test "vehicles with no activity in the range are omitted", %{scope: scope} do
      vehicle_fixture(scope, %{name: "Idle"})
      assert Reports.cost_of_ownership_report(scope, %{}).rows == []
    end
  end

  describe "fuel & economy" do
    test "computes per-fill economy from the distance since the previous fill", %{scope: scope} do
      import Fleetms.FuelFixtures

      vehicle = vehicle_fixture(scope)
      now = DateTime.utc_now()

      fuel_entry_fixture(scope, %{
        vehicle_id: vehicle.id,
        refueled_at: DateTime.add(now, -1, :day),
        odometer: Decimal.new("1000"),
        quantity: Decimal.new("40"),
        cost: Money.new(:ZMW, "80.00")
      })

      fuel_entry_fixture(scope, %{
        vehicle_id: vehicle.id,
        refueled_at: now,
        odometer: Decimal.new("1200"),
        quantity: Decimal.new("20"),
        cost: Money.new(:ZMW, "40.00")
      })

      report = Reports.fuel_report(scope, %{})

      # Newest first: the second fill has economy, the first (no prior) doesn't.
      assert [newest, oldest] = report.rows
      assert %{distance_km: d, fuel_l: f} = newest.economy
      assert Decimal.equal?(d, Decimal.new("200"))
      assert Decimal.equal?(f, Decimal.new("20"))
      assert oldest.economy == nil

      assert Decimal.equal?(report.summary.quantity, Decimal.new("60"))
      assert Decimal.equal?(report.summary.cost, Decimal.new("120.00"))
      assert Decimal.equal?(report.summary.distance, Decimal.new("200"))
    end
  end

  describe "vehicle roster" do
    test "lists the fleet, sorted by name, filterable by status", %{scope: scope} do
      vehicle_fixture(scope, %{name: "Alpha", status: :Active})
      vehicle_fixture(scope, %{name: "Zulu", status: :Sold})

      all = Reports.vehicle_roster(scope, %{})
      assert all.summary.count == 2
      assert Enum.map(all.rows, & &1.name) == ["Alpha", "Zulu"]

      sold = Reports.vehicle_roster(scope, %{"status" => "Sold"})
      assert [%{name: "Zulu", status: :Sold}] = sold.rows
    end
  end
end
