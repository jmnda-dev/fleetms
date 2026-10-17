defmodule FleetmsWeb.JsonApiRolesTest do
  @moduledoc "JSON:API for org-level role management (roles, user-roles, permissions)."
  use FleetmsWeb.ConnCase

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

    %{conn: conn, org: org, owner: owner}
  end

  test "creates a role, lists it, and sets its permissions", %{conn: conn, org: org, owner: owner} do
    body = %{
      data: %{
        type: "role",
        attributes: %{name: "API Role", description: "made via API", organization_id: org.id}
      }
    }

    assert %{"data" => %{"id" => role_id}} =
             json_response(post(conn, "/api/v1/roles", Jason.encode!(body)), 201)

    # The new role shows up in the list.
    assert %{"data" => roles} = json_response(get(conn, "/api/v1/roles"), 200)
    assert Enum.any?(roles, &(&1["id"] == role_id))

    # The permission catalog endpoint is readable (seeded on boot; may be empty in test).
    assert %{"data" => _} = json_response(get(conn, "/api/v1/permissions"), 200)

    # set_permissions works (clearing to an empty set here, since the catalog isn't
    # seeded in the test sandbox).
    set = %{data: %{type: "role", id: role_id, attributes: %{permission_ids: []}}}

    assert json_response(
             patch(conn, "/api/v1/roles/#{role_id}/permissions", Jason.encode!(set)),
             200
           )

    # And assign it to the owner.
    ur = %{data: %{type: "user-role", attributes: %{user_id: owner.id, role_id: role_id}}}
    assert json_response(post(conn, "/api/v1/user-roles", Jason.encode!(ur)), 201)
  end
end
