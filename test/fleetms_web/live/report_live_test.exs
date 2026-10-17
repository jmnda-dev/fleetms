defmodule FleetmsWeb.ReportLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.InventoryFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  defp work_order_with_part(scope, vehicle, task) do
    Maintenance.create_work_order!(
      %{
        vehicle_id: vehicle.id,
        work_order_service_tasks: [
          %{
            service_task_id: task.id,
            work_order_service_task_parts: [
              %{
                part_id: part_fixture(scope).id,
                quantity: Decimal.new("2"),
                unit_cost: Money.new(:ZMW, "10.00")
              }
            ]
          }
        ]
      },
      scope: scope
    )
  end

  test "the reports index lists every report", %{conn: conn, org: org} do
    {:ok, _view, html} = live(conn, ~p"/o/#{org}/reports")

    assert html =~ "Maintenance &amp; cost history"
    assert html =~ "Cost of ownership"
    assert html =~ "Fuel &amp; economy"
    assert html =~ "Vehicle roster"
    # All four are built now — nothing "Soon".
    refute html =~ "Soon"
  end

  test "the cost-of-ownership report shows a vehicle's spend", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    import Fleetms.FuelFixtures

    vehicle = vehicle_fixture(scope, %{name: "Tcorig"})
    task = service_task_fixture(scope)
    wo = work_order_with_part(scope, vehicle, task)
    Maintenance.complete_work_order!(wo, scope: scope)

    fuel_entry_fixture(scope, %{
      vehicle_id: vehicle.id,
      cost: Money.new(:ZMW, "150.00"),
      odometer: Decimal.new("100")
    })

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/reports/cost-of-ownership")

    assert html =~ "Cost of ownership"
    assert html =~ "Tcorig"
    assert html =~ "ZMW 150"
    assert html =~ "Export CSV"
    assert html =~ "/reports/cost-of-ownership.csv"
  end

  test "the maintenance report shows rows, totals and an export link", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Reprig"})
    task = service_task_fixture(scope)
    work_order_with_part(scope, vehicle, task)

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/reports/maintenance")

    assert html =~ "Maintenance &amp; cost history"
    assert html =~ "Reprig"
    assert html =~ "ZMW 20"
    assert html =~ "Export CSV"
    assert html =~ "/reports/maintenance.csv"
  end

  test "the fuel report shows a fill-up with its economy", %{conn: conn, org: org, scope: scope} do
    import Fleetms.FuelFixtures

    vehicle = vehicle_fixture(scope, %{name: "Fuelrig"})
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

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/reports/fuel")

    assert html =~ "Fuel &amp; economy"
    assert html =~ "Fuelrig"
    # 20 L over 200 km = 10 L/100km.
    assert html =~ "10 L/100km"
    assert html =~ "/reports/fuel.csv"
  end

  test "the roster lists the fleet and filters by status", %{conn: conn, org: org, scope: scope} do
    vehicle_fixture(scope, %{name: "Rostervan", status: :Active})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/reports/roster")
    assert html =~ "Vehicle roster"
    assert html =~ "Rostervan"
    assert html =~ "/reports/roster.csv"

    {:ok, _view, sold} = live(conn, ~p"/o/#{org}/reports/roster?#{%{status: "Sold"}}")
    refute sold =~ "Rostervan"
  end

  test "the status filter (via the URL) narrows the rows", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Openrig"})
    task = service_task_fixture(scope)
    work_order_with_part(scope, vehicle, task)

    # Unfiltered, the open work order's row shows (no empty state).
    {:ok, _view, html} = live(conn, ~p"/o/#{org}/reports/maintenance")
    assert html =~ "Openrig"
    refute html =~ "No work orders in this range."

    # Filtering to completed (the filter form patches to this URL) empties the table.
    {:ok, _view, filtered} =
      live(conn, ~p"/o/#{org}/reports/maintenance?#{%{status: "completed"}}")

    assert filtered =~ "No work orders in this range."
  end
end
