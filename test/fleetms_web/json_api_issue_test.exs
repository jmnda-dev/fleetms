defmodule FleetmsWeb.JsonApiIssueTest do
  @moduledoc "JSON:API for issues, including the resolve custom action."
  use FleetmsWeb.ConnCase

  import Fleetms.VehicleFixtures
  import Fleetms.IssueFixtures

  alias Fleetms.Scope
  alias Fleetms.VehicleIssues

  @ct "application/vnd.api+json"

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(owner)

    conn =
      conn
      |> put_req_header("accept", @ct)
      |> put_req_header("content-type", @ct)
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("x-organization", org.public_id)

    %{conn: conn, org: org, scope: Scope.new(owner, org, true)}
  end

  test "creates an issue via POST", %{conn: conn, scope: scope} do
    vehicle = vehicle_fixture(scope)
    body = %{data: %{type: "issue", attributes: %{title: "API fault", vehicle_id: vehicle.id}}}

    conn = post(conn, "/api/v1/issues", Jason.encode!(body))

    assert %{"data" => %{"id" => id}} = json_response(conn, 201)
    assert {:ok, _} = VehicleIssues.get_issue(id, scope: scope)
  end

  test "resolves an issue via the custom action route", %{conn: conn, scope: scope} do
    issue = issue_fixture(scope, %{title: "To resolve"})
    body = %{data: %{type: "issue", id: issue.id, attributes: %{}}}

    conn = patch(conn, "/api/v1/issues/#{issue.id}/resolve", Jason.encode!(body))

    assert json_response(conn, 200)
    assert VehicleIssues.get_issue!(issue.id, scope: scope).status == :resolved
  end

  test "lists issues", %{conn: conn, scope: scope} do
    issue_fixture(scope, %{title: "Listed"})
    conn = get(conn, "/api/v1/issues")
    assert %{"data" => data} = json_response(conn, 200)
    assert length(data) >= 1
  end
end
