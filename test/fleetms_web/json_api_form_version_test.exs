defmodule FleetmsWeb.JsonApiFormVersionTest do
  @moduledoc "Fetching an inspection's form version (the questions) over the JSON:API."
  use FleetmsWeb.ConnCase

  import Fleetms.InspectionFixtures

  alias Fleetms.Scope

  @ct "application/vnd.api+json"

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(owner)

    conn =
      conn
      |> put_req_header("accept", @ct)
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("x-organization", org.public_id)

    %{conn: conn, org: org, scope: Scope.new(owner, org, true)}
  end

  test "an inspection's form version is fetchable by id and carries its schema", %{
    conn: conn,
    scope: scope
  } do
    {_form, version} = published_version_fixture(scope)
    inspection = inspection_fixture(scope, version)

    # The inspection exposes the version id...
    insp = json_response(get(conn, "/api/v1/inspections/#{inspection.id}"), 200)
    version_id = insp["data"]["attributes"]["inspection_form_version_id"]
    assert version_id == version.id

    # ...and that id now resolves to the form version, with its question schema.
    ver = json_response(get(conn, "/api/v1/inspection-form-versions/#{version_id}"), 200)
    assert ver["data"]["id"] == version.id
    assert ver["data"]["attributes"]["version_number"] == version.version_number
    assert ver["data"]["attributes"]["schema"]
  end
end
