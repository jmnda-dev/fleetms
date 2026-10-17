defmodule FleetmsWeb.PartStockLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.InventoryFixtures

  alias Fleetms.Inventory
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "shows per-location stock and total on hand", %{conn: conn, org: org, scope: scope} do
    part = part_fixture(scope, %{part_number: "OILFILTER", track_inventory: true})
    warehouse = inventory_location_fixture(scope, %{name: "Warehouse"})
    van = inventory_location_fixture(scope, %{name: "Van 3"})
    part_stock_fixture(scope, part, warehouse, Decimal.new("50"))
    part_stock_fixture(scope, part, van, Decimal.new("100"))

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/stock")

    assert html =~ "OILFILTER"
    assert html =~ "Warehouse"
    assert html =~ "Van 3"
    # Whole numbers render plainly, not in scientific notation (50 not "5E+1").
    assert html =~ "50"
    assert html =~ "150"
    refute html =~ "E+"
  end

  test "transfers stock from one location to another", %{conn: conn, org: org, scope: scope} do
    part = part_fixture(scope, %{track_inventory: true})
    warehouse = inventory_location_fixture(scope, %{name: "Warehouse"})
    van = inventory_location_fixture(scope, %{name: "Van 3"})
    part_stock_fixture(scope, part, warehouse, Decimal.new("50"))

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/stock")

    from_stock =
      Inventory.list_part_stocks!(part.id, scope: scope)
      |> Enum.find(&(&1.inventory_location_id == warehouse.id))

    render_submit(view, "transfer", %{
      "from_id" => from_stock.id,
      "to_location_id" => van.id,
      "amount" => "20"
    })

    stocks = Inventory.list_part_stocks!(part.id, scope: scope)
    warehouse_qty = Enum.find(stocks, &(&1.inventory_location_id == warehouse.id)).quantity
    van_qty = Enum.find(stocks, &(&1.inventory_location_id == van.id)).quantity

    assert Decimal.equal?(warehouse_qty, Decimal.new("30"))
    assert Decimal.equal?(van_qty, Decimal.new("20"))
  end

  test "won't transfer more than the source holds", %{conn: conn, org: org, scope: scope} do
    part = part_fixture(scope, %{track_inventory: true})
    warehouse = inventory_location_fixture(scope, %{name: "Warehouse"})
    van = inventory_location_fixture(scope, %{name: "Van 3"})
    part_stock_fixture(scope, part, warehouse, Decimal.new("5"))

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/stock")

    from_stock =
      Inventory.list_part_stocks!(part.id, scope: scope)
      |> Enum.find(&(&1.inventory_location_id == warehouse.id))

    html =
      render_submit(view, "transfer", %{
        "from_id" => from_stock.id,
        "to_location_id" => van.id,
        "amount" => "20"
      })

    assert html =~ "have that much stock"

    warehouse_qty =
      Inventory.list_part_stocks!(part.id, scope: scope)
      |> Enum.find(&(&1.inventory_location_id == warehouse.id))
      |> Map.fetch!(:quantity)

    assert Decimal.equal?(warehouse_qty, Decimal.new("5"))
  end

  test "adds stock at a new location", %{conn: conn, org: org, scope: scope} do
    part = part_fixture(scope)
    location = inventory_location_fixture(scope, %{name: "Depot"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/stock")

    view
    |> form("form[phx-submit=add-stock]", %{location_id: location.id, quantity: "15"})
    |> render_submit()

    assert {:ok, [stock]} = Inventory.list_part_stocks(part.id, scope: scope)
    assert Decimal.equal?(stock.quantity, Decimal.new("15"))
  end

  test "receives and consumes stock at a location", %{conn: conn, org: org, scope: scope} do
    part = part_fixture(scope)
    location = inventory_location_fixture(scope)
    stock = part_stock_fixture(scope, part, location, Decimal.new("10"))

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/stock")

    render_submit(form_for_stock(view, stock), %{amount: "5", action: "receive"})
    assert Decimal.equal?(reload_qty(scope, stock), Decimal.new("15"))

    render_submit(form_for_stock(view, stock), %{amount: "6", action: "consume"})
    assert Decimal.equal?(reload_qty(scope, stock), Decimal.new("9"))
  end

  test "refuses to consume below zero", %{conn: conn, org: org, scope: scope} do
    part = part_fixture(scope)
    location = inventory_location_fixture(scope)
    stock = part_stock_fixture(scope, part, location, Decimal.new("3"))

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/stock")

    html = render_submit(form_for_stock(view, stock), %{amount: "10", action: "consume"})

    assert html =~ "below zero"
    assert Decimal.equal?(reload_qty(scope, stock), Decimal.new("3"))
  end

  test "removes a location's stock record", %{conn: conn, org: org, scope: scope} do
    part = part_fixture(scope)
    location = inventory_location_fixture(scope)
    stock = part_stock_fixture(scope, part, location, Decimal.new("5"))

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/stock")

    view
    |> element(~s|button[phx-click="remove-stock"][phx-value-id="#{stock.id}"]|)
    |> render_click()

    assert {:ok, []} = Inventory.list_part_stocks(part.id, scope: scope)
  end

  defp form_for_stock(view, stock) do
    element(view, ~s|form[phx-submit=adjust]:has(input[value="#{stock.id}"])|)
  end

  defp reload_qty(scope, stock) do
    Inventory.get_part_stock!(stock.id, scope: scope).quantity
  end
end
