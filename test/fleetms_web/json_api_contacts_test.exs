defmodule FleetmsWeb.JsonApiContactsTest do
  @moduledoc "JSON:API for contacts (the org's address book of external parties)."
  use FleetmsWeb.ConnCase

  alias Fleetms.Contacts
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

  test "lists contacts", %{conn: conn} do
    assert %{"data" => _} = json_response(get(conn, "/api/v1/contacts"), 200)
  end

  test "creates a contact via POST", %{conn: conn, scope: scope} do
    body = %{
      data: %{
        type: "contact",
        attributes: %{name: "Acme Insurers", contact_type: "insurer", email: "hi@acme.test"}
      }
    }

    conn = post(conn, "/api/v1/contacts", Jason.encode!(body))

    assert %{"data" => %{"id" => id, "attributes" => attrs}} = json_response(conn, 201)
    assert attrs["name"] == "Acme Insurers"
    assert {:ok, _} = Contacts.get_contact(id, scope: scope)
  end
end
