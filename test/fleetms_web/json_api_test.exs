defmodule FleetmsWeb.JsonApiTest do
  @moduledoc "The public JSON:API: bearer auth + x-organization tenant, over vehicles."
  use FleetmsWeb.ConnCase

  import Fleetms.VehicleFixtures

  alias Fleetms.Scope

  @accept "application/vnd.api+json"

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(owner)
    %{conn: conn, owner: owner, org: org, token: token, scope: Scope.new(owner, org, true)}
  end

  defp api_conn(conn, token, org) do
    conn
    |> put_req_header("accept", @accept)
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("x-organization", org.public_id)
  end

  test "lists the org's vehicles for an authenticated member", ctx do
    %{conn: conn, token: token, org: org, scope: scope} = ctx
    vehicle = vehicle_fixture(scope, %{name: "API Truck"})

    conn = conn |> api_conn(token, org) |> get("/api/v1/vehicles")

    assert %{"data" => data} = json_response(conn, 200)
    assert Enum.any?(data, &(&1["id"] == vehicle.id and &1["type"] == "vehicle"))
  end

  test "fetches a single vehicle by id", ctx do
    %{conn: conn, token: token, org: org, scope: scope} = ctx
    vehicle = vehicle_fixture(scope, %{name: "Single"})

    conn = conn |> api_conn(token, org) |> get("/api/v1/vehicles/#{vehicle.id}")

    assert %{"data" => %{"id" => id, "type" => "vehicle"}} = json_response(conn, 200)
    assert id == vehicle.id
  end

  test "rejects a request with no bearer token", %{conn: conn, org: org} do
    conn =
      conn
      |> put_req_header("accept", @accept)
      |> put_req_header("x-organization", org.public_id)
      |> get("/api/v1/vehicles")

    assert response(conn, 401)
  end

  test "rejects a request with no organization header", %{conn: conn, token: token} do
    conn =
      conn
      |> put_req_header("accept", @accept)
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/v1/vehicles")

    assert response(conn, 400)
  end

  test "an API key authenticates the same as a bearer token", ctx do
    %{conn: conn, owner: owner, org: org, scope: scope} = ctx
    vehicle = vehicle_fixture(scope, %{name: "Keyed"})

    expires = DateTime.add(DateTime.utc_now(), 30, :day)

    key =
      Fleetms.Accounts.create_api_key!(%{user_id: owner.id, expires_at: expires}, actor: owner)

    plaintext = key.__metadata__.plaintext_api_key

    conn =
      conn
      |> put_req_header("accept", @accept)
      |> put_req_header("authorization", "Bearer #{plaintext}")
      |> put_req_header("x-organization", org.public_id)
      |> get("/api/v1/vehicles")

    assert %{"data" => data} = json_response(conn, 200)
    assert Enum.any?(data, &(&1["id"] == vehicle.id))
  end

  test "an invalid API key is rejected", %{conn: conn, org: org} do
    conn =
      conn
      |> put_req_header("accept", @accept)
      |> put_req_header("authorization", "Bearer fleetms_notarealkey_00000")
      |> put_req_header("x-organization", org.public_id)
      |> get("/api/v1/vehicles")

    assert response(conn, 401)
  end

  # The OpenAPI spec + Swagger UI are now served publicly; covered by
  # FleetmsWeb.ApiDocsSigninTest.
end
