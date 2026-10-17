defmodule FleetmsWeb.CalendarLiveTest do
  @moduledoc "The calendar renders the month grid and shows dated fleet events."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures

  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "renders the current month grid with weekday headers", %{conn: conn, org: org} do
    {:ok, _view, html} = live(conn, ~p"/o/#{org}/calendar")

    assert html =~ Calendar.strftime(Date.utc_today(), "%B %Y")
    assert html =~ "Mon"
    assert html =~ "Sun"
    assert html =~ "Reminders"
    assert html =~ "Inspections"
  end

  test "a renewal due this month appears as an event", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Grader 3"})
    type = renewal_type_fixture(scope, "Road Tax")
    due = Date.utc_today()

    VehicleManagement.create_vehicle_renewal!(
      %{vehicle_id: vehicle.id, renewal_type_id: type.id, due_date: due},
      scope: scope
    )

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/calendar")

    assert html =~ "Road Tax"
  end

  test "navigating to a far-off month drops this month's events", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Grader 3"})
    type = renewal_type_fixture(scope, "Road Tax")

    VehicleManagement.create_vehicle_renewal!(
      %{vehicle_id: vehicle.id, renewal_type_id: type.id, due_date: Date.utc_today()},
      scope: scope
    )

    far = Date.utc_today() |> Date.add(400) |> Calendar.strftime("%Y-%m")
    {:ok, _view, html} = live(conn, ~p"/o/#{org}/calendar?month=#{far}")

    refute html =~ "Road Tax"
  end
end
