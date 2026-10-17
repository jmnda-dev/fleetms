defmodule FleetmsWeb.JsonApiVehicleCrudTest do
  @moduledoc "Full CRUD + a custom action over the JSON:API for vehicles."
  use FleetmsWeb.ConnCase

  import Fleetms.VehicleFixtures

  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

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

  test "creates a vehicle via POST", %{conn: conn, scope: scope} do
    body = %{data: %{type: "vehicle", attributes: %{name: "API-made", type: "Truck"}}}

    conn = post(conn, "/api/v1/vehicles", Jason.encode!(body))

    assert %{"data" => %{"id" => id, "attributes" => attrs}} = json_response(conn, 201)
    assert attrs["name"] == "API-made"
    assert {:ok, _} = VehicleManagement.get_vehicle(id, scope: scope)
  end

  test "updates a vehicle via PATCH", %{conn: conn, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Before"})
    body = %{data: %{type: "vehicle", id: vehicle.id, attributes: %{name: "After"}}}

    conn = patch(conn, "/api/v1/vehicles/#{vehicle.id}", Jason.encode!(body))

    assert %{"data" => %{"attributes" => %{"name" => "After"}}} = json_response(conn, 200)
  end

  test "changes status via the custom action route", %{conn: conn, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Statusable", status: :Active})
    body = %{data: %{type: "vehicle", id: vehicle.id, attributes: %{status: "Maintenance"}}}

    conn = patch(conn, "/api/v1/vehicles/#{vehicle.id}/status", Jason.encode!(body))

    assert json_response(conn, 200)
    assert VehicleManagement.get_vehicle!(vehicle.id, scope: scope).status == :Maintenance
  end

  test "deletes (archives) a vehicle via DELETE", %{conn: conn, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Doomed"})

    conn = delete(conn, "/api/v1/vehicles/#{vehicle.id}")

    assert conn.status in [200, 204]
    assert {:error, _} = VehicleManagement.get_vehicle(vehicle.id, scope: scope)
  end
end
