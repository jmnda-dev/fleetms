defmodule FleetmsWeb.ApiMembersTest do
  @moduledoc "The members API: list, add by email, suspend/reactivate, remove."
  use FleetmsWeb.ConnCase

  alias Fleetms.Accounts

  @accept "application/vnd.api+json"

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(owner)

    conn =
      conn
      |> put_req_header("accept", @accept)
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("x-organization", org.public_id)

    %{conn: conn, owner: owner, org: org}
  end

  test "lists the organization's members", %{conn: conn, owner: owner} do
    assert %{"data" => data} = json_response(get(conn, "/api/v1/members"), 200)
    assert Enum.any?(data, &(&1["attributes"]["user_id"] == owner.id and &1["type"] == "member"))
  end

  test "adds an existing user to the organization by email", %{conn: conn} do
    invitee = user_fixture()

    resp =
      conn
      |> post("/api/v1/members", %{"email" => invitee.email |> to_string()})
      |> json_response(201)

    assert %{"data" => %{"type" => "member", "attributes" => attrs}} = resp
    assert attrs["user_id"] == invitee.id
    assert attrs["status"] == "active"

    assert %{"data" => data} = json_response(get(conn, "/api/v1/members"), 200)
    assert Enum.any?(data, &(&1["attributes"]["user_id"] == invitee.id))
  end

  test "sends an invitation when no account exists yet", %{conn: conn} do
    email = "newcomer-#{System.unique_integer([:positive])}@example.com"

    resp = conn |> post("/api/v1/members", %{"email" => email}) |> json_response(201)
    assert %{"data" => %{"type" => "invitation", "attributes" => %{"status" => "invited"}}} = resp
  end

  test "requires an email", %{conn: conn} do
    assert %{"errors" => _} = json_response(post(conn, "/api/v1/members", %{}), 400)
  end

  test "suspends and reactivates a member", %{conn: conn} do
    invitee = user_fixture()

    %{"data" => %{"id" => id}} =
      conn
      |> post("/api/v1/members", %{"email" => to_string(invitee.email)})
      |> json_response(201)

    assert %{"data" => %{"attributes" => %{"status" => "suspended"}}} =
             json_response(post(conn, "/api/v1/members/#{id}/suspend"), 200)

    assert %{"data" => %{"attributes" => %{"status" => "active"}}} =
             json_response(post(conn, "/api/v1/members/#{id}/reactivate"), 200)
  end

  test "removes a member", %{conn: conn} do
    invitee = user_fixture()

    %{"data" => %{"id" => id}} =
      conn
      |> post("/api/v1/members", %{"email" => to_string(invitee.email)})
      |> json_response(201)

    assert response(delete(conn, "/api/v1/members/#{id}"), 204)

    assert %{"data" => data} = json_response(get(conn, "/api/v1/members"), 200)
    refute Enum.any?(data, &(&1["attributes"]["user_id"] == invitee.id))
  end

  test "the owner cannot remove themselves (last owner)", %{conn: conn, owner: owner, org: org} do
    membership =
      Accounts.list_user_organizations!(authorize?: false)
      |> Enum.find(&(&1.user_id == owner.id and &1.organization_id == org.id))

    assert %{"errors" => _} = json_response(delete(conn, "/api/v1/members/#{membership.id}"), 422)
  end

  test "a member id from another org is not addressable", %{conn: conn} do
    {other_owner, other_org} = user_with_org_fixture()

    membership =
      Accounts.list_user_organizations!(authorize?: false)
      |> Enum.find(&(&1.user_id == other_owner.id and &1.organization_id == other_org.id))

    assert %{"errors" => _} = json_response(delete(conn, "/api/v1/members/#{membership.id}"), 404)
  end
end
