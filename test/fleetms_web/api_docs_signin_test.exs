defmodule FleetmsWeb.ApiDocsSigninTest do
  @moduledoc "Public API docs (OpenAPI + Swagger UI) and the token login endpoint."
  use FleetmsWeb.ConnCase

  @ct "application/vnd.api+json"

  test "serves the OpenAPI spec publicly (no auth, no org header)", %{conn: conn} do
    conn = conn |> put_req_header("accept", "application/json") |> get("/api/v1/open_api")

    assert conn.status == 200
    assert %{"openapi" => _, "paths" => paths} = Jason.decode!(conn.resp_body)
    assert Enum.any?(Map.keys(paths), &String.contains?(&1, "vehicles"))
  end

  test "serves the Swagger UI publicly", %{conn: conn} do
    conn = conn |> put_req_header("accept", "text/html") |> get("/api/v1/docs")

    assert conn.status == 200
    assert conn.resp_body =~ "swagger"
  end

  test "token login returns a JWT that authenticates the API", %{conn: conn} do
    {owner, org} = user_with_org_fixture()

    login =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(
        "/api/v1/sign-in",
        Jason.encode!(%{email: to_string(owner.email), password: "password1234"})
      )

    assert %{"token" => token, "token_type" => "Bearer", "organizations" => orgs} =
             json_response(login, 200)

    # The response tells the client which org public_id to use.
    assert Enum.any?(orgs, &(&1["public_id"] == org.public_id and &1["name"] == org.name))
    membership = Enum.find(orgs, &(&1["public_id"] == org.public_id))
    assert membership["owner"] == true

    # The returned token + org public_id work on a data endpoint.
    api =
      build_conn()
      |> put_req_header("accept", @ct)
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("x-organization", membership["public_id"])
      |> get("/api/v1/vehicles")

    assert %{"data" => _} = json_response(api, 200)
  end

  test "token login rejects bad credentials", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/sign-in", Jason.encode!(%{email: "nobody@example.com", password: "wrong"}))

    assert response(conn, 401)
  end
end
