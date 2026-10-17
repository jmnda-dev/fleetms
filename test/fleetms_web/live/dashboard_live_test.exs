defmodule FleetmsWeb.DashboardLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.IssueFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "renders the KPI tiles and fleet status", %{conn: conn, org: org, scope: scope} do
    vehicle_fixture(scope, %{status: :Active})
    issue_fixture(scope)

    {:ok, _view, html} = live(conn, ~p"/o/#{org}")

    assert html =~ "Active vehicles"
    assert html =~ "Open issues"
    assert html =~ "Work orders in progress"
    assert html =~ "Coming due"
    assert html =~ "Fleet status"
  end

  test "reflects real counts", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{status: :Active})
    vehicle_fixture(scope, %{status: :Active})
    vehicle_fixture(scope, %{status: :Maintenance})

    # Two issues on the existing vehicle (so the fleet size stays 3), one overdue.
    issue_fixture(scope, %{vehicle_id: vehicle.id})
    issue_fixture(scope, %{vehicle_id: vehicle.id, due_date: Date.add(Date.utc_today(), -2)})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}")

    assert html =~ "of 3 in fleet"
    assert html =~ "1 overdue"
  end

  test "empty fleet shows the no-vehicles note", %{conn: conn, org: org} do
    {:ok, _view, html} = live(conn, ~p"/o/#{org}")
    assert html =~ "No vehicles yet."
  end

  describe "getting-started checklist" do
    test "a brand-new org sees the checklist with all steps open", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}")

      assert html =~ "Get started"
      assert html =~ "0 of 3 done"
      assert html =~ "Add your first vehicle"
      assert html =~ "Report an issue"
      assert html =~ "Schedule a service reminder"
    end

    test "adding a vehicle ticks a step off", %{conn: conn, org: org, scope: scope} do
      vehicle_fixture(scope, %{status: :Active})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}")

      assert html =~ "Get started"
      assert html =~ "1 of 3 done"
    end

    test "once every step is done the checklist is gone", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{status: :Active})
      issue_fixture(scope, %{vehicle_id: vehicle.id})
      service_reminder_fixture(scope, vehicle, service_task_fixture(scope))

      {:ok, _view, html} = live(conn, ~p"/o/#{org}")

      refute html =~ "Get started"
    end
  end

  test "renders the chart containers wired to the Chart hook with specs", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope)
    issue_fixture(scope, %{vehicle_id: vehicle.id})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}")

    assert html =~ "Issues opened vs resolved"
    assert html =~ "Spend"
    assert html =~ "Open issues by priority"
    # Each chart container carries the hook and a JSON spec for ECharts.
    assert html =~ ~s(phx-hook="Chart")
    assert html =~ "chart-issues-trend"
    assert html =~ "&quot;kind&quot;:&quot;line&quot;"
  end

  test "renders the attention lists with their empty states", %{conn: conn, org: org} do
    {:ok, _view, html} = live(conn, ~p"/o/#{org}")

    assert html =~ "Service due"
    assert html =~ "Renewals due"
    assert html =~ "Recently reported issues"
    assert html =~ "Low stock"
    # Empty states show when there's nothing to surface.
    assert html =~ "No issues reported yet."
    assert html =~ "Stock levels look healthy."
  end

  test "a recently reported issue appears in the attention list", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Loader-9"})
    issue_fixture(scope, %{vehicle_id: vehicle.id, title: "Coolant leak"})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}")

    assert html =~ "Coolant leak"
    assert html =~ "Loader-9"
  end
end
