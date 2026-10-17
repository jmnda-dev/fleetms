defmodule FleetmsWeb.WorkOrderFromIssueTest do
  @moduledoc "Creating a work order straight from an issue, with the issue linked."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.IssueFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "an open issue shows a Create work order button pre-filled with the vehicle and issue",
       %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Loader 1"})
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/issues/#{issue.id}")

    assert html =~ "Create work order"
    assert html =~ "/work-orders/new?"
    assert html =~ "vehicle_id=#{vehicle.id}"
    assert html =~ "issue_ids%5B%5D=#{issue.id}" or html =~ "issue_ids[]=#{issue.id}"
  end

  test "the new work-order form pre-selects the vehicle from the query params", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Loader 1"})
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})

    {:ok, _view, html} =
      live(
        conn,
        ~p"/o/#{org}/work-orders/new?#{%{"vehicle_id" => vehicle.id, "issue_ids" => [issue.id]}}"
      )

    # The issue is offered as a selectable/linked option on the form.
    assert html =~ issue.title
  end
end
