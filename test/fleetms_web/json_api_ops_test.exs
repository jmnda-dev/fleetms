defmodule FleetmsWeb.JsonApiOpsTest do
  @moduledoc "JSON:API for fuel, expenses and drivers."
  use FleetmsWeb.ConnCase

  alias Fleetms.Drivers
  alias Fleetms.Scope

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

  test "index routes respond", %{conn: conn} do
    for path <- ~w(/api/v1/fuel-entries /api/v1/expenses /api/v1/drivers) do
      assert %{"data" => _} = json_response(get(conn, path), 200)
    end
  end

  test "creates a driver via POST", %{conn: conn, scope: scope} do
    body = %{data: %{type: "driver", attributes: %{first_name: "Api", last_name: "Driver"}}}
    conn = post(conn, "/api/v1/drivers", Jason.encode!(body))

    assert %{"data" => %{"id" => id}} = json_response(conn, 201)
    assert {:ok, _} = Drivers.get_driver(id, scope: scope)
  end
end
