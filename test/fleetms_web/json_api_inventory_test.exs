defmodule FleetmsWeb.JsonApiInventoryTest do
  @moduledoc "JSON:API for inventory (parts, stock, locations) and tags."
  use FleetmsWeb.ConnCase

  import Fleetms.InventoryFixtures

  alias Fleetms.Inventory
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
    for path <- ~w(/api/v1/parts /api/v1/part-stocks /api/v1/inventory-locations /api/v1/tags) do
      assert %{"data" => _} = json_response(get(conn, path), 200)
    end
  end

  test "creates a part via POST", %{conn: conn, scope: scope} do
    body = %{data: %{type: "part", attributes: %{part_number: "API-PN-1", name: "Widget"}}}
    conn = post(conn, "/api/v1/parts", Jason.encode!(body))

    assert %{"data" => %{"id" => id}} = json_response(conn, 201)
    assert {:ok, _} = Inventory.get_part(id, scope: scope)
  end

  test "adjusts stock via the custom action route", %{conn: conn, scope: scope} do
    part = part_fixture(scope, %{track_inventory: true})
    location = inventory_location_fixture(scope)
    stock = part_stock_fixture(scope, part, location, Decimal.new("5"))

    body = %{data: %{type: "part-stock", id: stock.id, attributes: %{delta: 3}}}
    conn = patch(conn, "/api/v1/part-stocks/#{stock.id}/adjust", Jason.encode!(body))

    assert json_response(conn, 200)

    assert Decimal.equal?(
             Inventory.get_part_stock!(stock.id, scope: scope).quantity,
             Decimal.new("8")
           )
  end
end
