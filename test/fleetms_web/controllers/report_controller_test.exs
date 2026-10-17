defmodule FleetmsWeb.ReportControllerTest do
  use FleetmsWeb.ConnCase

  import Fleetms.InventoryFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  defp work_order_with_part(scope, vehicle, task, unit_cost, qty) do
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

  test "downloads the maintenance report as a CSV attachment", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "CsvRig"})
    task = service_task_fixture(scope)
    work_order_with_part(scope, vehicle, task, "10.00", Decimal.new("2"))

    conn = get(conn, ~p"/o/#{org}/reports/maintenance.csv")

    body = response(conn, 200)
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/csv"

    assert get_resp_header(conn, "content-disposition") |> hd() =~
             ~s(filename="maintenance-report.csv")

    assert body =~ "Work order,Vehicle,Issued,Status,Tasks,Parts,Labour,Total,Currency"
    assert body =~ "CsvRig"
    # 2 × 10.00 = 20.00, plain decimal for spreadsheets, currency named in its own column.
    assert body =~ "20.00"
    assert body =~ "ZMW"
  end

  test "a request for an organization the user isn't in is turned away", %{conn: conn} do
    {_other, other_org} = user_with_org_fixture()

    conn = get(conn, ~p"/o/#{other_org}/reports/maintenance.csv")
    assert redirected_to(conn) == ~p"/orgs"
  end

  test "downloads the cost-of-ownership report as CSV", %{conn: conn, org: org, scope: scope} do
    import Fleetms.FuelFixtures

    vehicle = vehicle_fixture(scope, %{name: "TcoRig"})
    task = service_task_fixture(scope)
    wo = work_order_with_part(scope, vehicle, task, "10.00", Decimal.new("2"))
    Fleetms.Maintenance.complete_work_order!(wo, scope: scope)

    fuel_entry_fixture(scope, %{
      vehicle_id: vehicle.id,
      cost: Money.new(:ZMW, "150.00"),
      odometer: Decimal.new("100")
    })

    conn = get(conn, ~p"/o/#{org}/reports/cost-of-ownership.csv")

    body = response(conn, 200)

    assert get_resp_header(conn, "content-disposition") |> hd() =~
             ~s(filename="cost-of-ownership.csv")

    assert body =~ "Vehicle,Maintenance,Fuel,Expenses,Total"
    assert body =~ "TcoRig"
    assert body =~ "150.00"
  end

  test "downloads the fuel report as CSV", %{conn: conn, org: org, scope: scope} do
    import Fleetms.FuelFixtures

    vehicle = vehicle_fixture(scope, %{name: "FuelCsv"})

    fuel_entry_fixture(scope, %{
      vehicle_id: vehicle.id,
      quantity: Decimal.new("30"),
      cost: Money.new(:ZMW, "60.00"),
      odometer: Decimal.new("500")
    })

    conn = get(conn, ~p"/o/#{org}/reports/fuel.csv")

    body = response(conn, 200)
    assert get_resp_header(conn, "content-disposition") |> hd() =~ ~s(filename="fuel-report.csv")
    assert body =~ "Date,Vehicle,Quantity"
    assert body =~ "FuelCsv"
  end

  test "downloads the vehicle roster as CSV", %{conn: conn, org: org, scope: scope} do
    vehicle_fixture(scope, %{name: "RosterCsv"})

    conn = get(conn, ~p"/o/#{org}/reports/roster.csv")

    body = response(conn, 200)

    assert get_resp_header(conn, "content-disposition") |> hd() =~
             ~s(filename="vehicle-roster.csv")

    assert body =~ "Name,Make,Model,Status"
    assert body =~ "RosterCsv"
  end
end
