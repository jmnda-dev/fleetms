defmodule FleetmsWeb.InventoryLiveTest do
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

  describe "locations" do
    test "lists locations with part counts and the new action", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      location = inventory_location_fixture(scope, %{name: "Main Store"})
      part = part_fixture(scope)
      part_stock_fixture(scope, part, location, Decimal.new("10"))

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/inventory-locations")

      assert html =~ "Inventory Locations"
      assert html =~ "New location"
      assert html =~ "Main Store"
    end

    test "creates a location", %{conn: conn, org: org, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/inventory-locations/new")

      view
      |> form("#location-form", location: %{name: "Depot 7", description: "North yard"})
      |> render_submit()

      assert [location] = Inventory.list_inventory_locations!(%{}, scope: scope)
      assert location.name == "Depot 7"
    end

    test "archives a location, then restores it from the archived view", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      location = inventory_location_fixture(scope, %{name: "Ghost Depot"})

      {:ok, view, html} = live(conn, ~p"/o/#{org}/inventory-locations")
      assert html =~ "Ghost Depot"

      # archive it — it disappears from the active list but is still resolvable
      view
      |> element(~s|button[phx-click="archive"][phx-value-id="#{location.id}"]|)
      |> render_click()

      refute render(view) =~ "Ghost Depot"
      assert {:ok, _} = Inventory.get_inventory_location(location.id, scope: scope)

      # it shows in the archived view with a Restore action
      {:ok, archived, html} = live(conn, ~p"/o/#{org}/inventory-locations?archived=1")
      assert html =~ "Archived locations"
      assert html =~ "Ghost Depot"
      assert html =~ "Restore"

      # restoring returns it to the active list
      archived
      |> element(~s|button[phx-click="restore"][phx-value-id="#{location.id}"]|)
      |> render_click()

      assert Enum.any?(
               Inventory.list_inventory_locations!(%{}, scope: scope),
               &(&1.id == location.id)
             )
    end
  end

  describe "parts" do
    test "lists parts with stock status and cost", %{conn: conn, org: org, scope: scope} do
      part =
        part_fixture(scope, %{
          part_number: "OILFILTER",
          unit_cost: Money.new(:USD, "9.99"),
          track_inventory: true,
          quantity_threshold: Decimal.new("2")
        })

      location = inventory_location_fixture(scope)
      part_stock_fixture(scope, part, location, Decimal.new("1"))

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/parts")

      assert html =~ "Parts"
      assert html =~ "New part"
      assert html =~ "OILFILTER"
      assert html =~ "9.99"
      # 1 on hand, threshold 2 → Low.
      assert html =~ "Low"
    end

    test "creates a part with a money cost", %{conn: conn, org: org, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/new")

      view
      |> form("#part-form",
        part: %{
          part_number: "BRAKEPAD-42",
          name: "Brake pad set",
          unit_cost: %{amount: "34.00", currency: "EUR"},
          track_inventory: "true",
          quantity_threshold: "4"
        }
      )
      |> render_submit()

      assert {:ok, page} =
               Inventory.list_parts(%{search_query: "BRAKEPAD-42"}, scope: scope)

      assert [part] = page.results
      assert part.name == "Brake pad set"
      assert part.track_inventory == true
      assert part.unit_cost.currency == :EUR
      assert Decimal.equal?(part.unit_cost.amount, Decimal.new("34.00"))
    end

    test "edits a part", %{conn: conn, org: org, scope: scope} do
      part = part_fixture(scope, %{part_number: "WIDGET-1"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts/#{part.id}/edit")

      view
      |> form("#part-form", part: %{name: "Renamed widget"})
      |> render_submit()

      assert {:ok, updated} = Inventory.get_part(part.id, scope: scope)
      assert updated.name == "Renamed widget"
    end

    test "filters by stock status", %{conn: conn, org: org, scope: scope} do
      low =
        part_fixture(scope, %{
          part_number: "LOWPART",
          track_inventory: true,
          quantity_threshold: 5
        })

      location = inventory_location_fixture(scope)
      part_stock_fixture(scope, low, location, Decimal.new("1"))

      _untracked = part_fixture(scope, %{part_number: "UNTRACKED"})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/parts")

      html =
        view
        |> form("#part-filters", %{statuses: ["Low"]})
        |> render_submit()

      assert html =~ "LOWPART"
      refute html =~ "UNTRACKED"
    end

    test "archives a part, then restores it from the archived view", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      part = part_fixture(scope, %{part_number: "ARCH-ME"})

      {:ok, view, html} = live(conn, ~p"/o/#{org}/parts")
      assert html =~ "ARCH-ME"

      # archive it from the active list — it disappears
      view
      |> element(~s|button[phx-click="archive"][phx-value-id="#{part.id}"]|)
      |> render_click()

      refute render(view) =~ "ARCH-ME"

      # it shows in the archived view with a Restore action
      {:ok, archived, html} = live(conn, ~p"/o/#{org}/parts?archived=1")
      assert html =~ "Archived parts"
      assert html =~ "ARCH-ME"
      assert html =~ "Restore"

      # restoring brings it back to the live catalogue
      archived
      |> element(~s|button[phx-click="restore"][phx-value-id="#{part.id}"]|)
      |> render_click()

      assert {:ok, page} = Inventory.list_parts(%{}, scope: scope)
      assert Enum.any?(page.results, &(&1.id == part.id))
    end
  end
end
