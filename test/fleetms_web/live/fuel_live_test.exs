defmodule FleetmsWeb.FuelLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.FuelFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.FuelManagement
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  describe "index" do
    test "lists entries and shows cost + the new action", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Truck-A"})
      fuel_entry_fixture(scope, %{vehicle_id: vehicle.id, cost: Money.new(:USD, "72.30")})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/fuel")

      assert html =~ "Fuel"
      assert html =~ "New fuel entry"
      assert html =~ "Truck-A"
      assert html =~ "72.30"
    end

    test "search narrows the list", %{conn: conn, org: org, scope: scope} do
      keep = vehicle_fixture(scope, %{name: "Zephyr"})
      drop = vehicle_fixture(scope, %{name: "Boxcar"})
      fuel_entry_fixture(scope, %{vehicle_id: keep.id})
      fuel_entry_fixture(scope, %{vehicle_id: drop.id})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/fuel")

      view |> form("form[phx-change=search]", %{q: "Zephyr"}) |> render_change()

      # Scope to the table — the vehicle names also appear in the filter drawer's
      # dropdown options, which search doesn't (and shouldn't) narrow.
      table = render(element(view, "table"))
      assert table =~ "Zephyr"
      refute table =~ "Boxcar"
    end
  end

  describe "new" do
    test "creates a fuel entry with a money cost", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/fuel/new")

      view
      |> form("#fuel-form",
        fuel_entry: %{
          vehicle_id: vehicle.id,
          refueled_at: "2026-07-01T09:00",
          odometer: "12000",
          quantity: "45.5",
          fuel_type: "gasoline",
          cost: %{amount: "80.25", currency: "EUR"}
        }
      )
      |> render_submit()

      assert {:ok, page} =
               FuelManagement.list_fuel_entries(
                 %{filters: %{"vehicle_id" => vehicle.id}},
                 scope: scope
               )

      assert [entry] = page.results
      assert entry.fuel_type == :gasoline
      assert entry.cost.currency == :EUR
      assert Decimal.equal?(entry.cost.amount, Decimal.new("80.25"))
      assert entry.refueled_at == ~U[2026-07-01 09:00:00Z]
    end
  end

  describe "edit" do
    test "updates a fuel entry", %{conn: conn, org: org, scope: scope} do
      entry = fuel_entry_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/fuel/#{entry.id}/edit")

      view
      |> form("#fuel-form", fuel_entry: %{location: "Shell, Cairo Rd"})
      |> render_submit()

      assert {:ok, updated} = FuelManagement.get_fuel_entry(entry.id, scope: scope)
      assert updated.location == "Shell, Cairo Rd"
    end
  end

  describe "archive / restore" do
    test "archives a fuel entry, then restores it from the archived view", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      entry = fuel_entry_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/fuel")

      view
      |> element(~s|button[phx-click="archive"][phx-value-id="#{entry.id}"]|)
      |> render_click()

      # archived — hidden everywhere, get can't resolve it
      assert {:error, _} = FuelManagement.get_fuel_entry(entry.id, scope: scope)

      {:ok, archived, html} = live(conn, ~p"/o/#{org}/fuel?archived=1")
      assert html =~ "Archived fuel entries"
      assert html =~ "Restore"

      archived
      |> element(~s|button[phx-click="restore"][phx-value-id="#{entry.id}"]|)
      |> render_click()

      assert Enum.any?(
               FuelManagement.list_fuel_entries!(%{}, scope: scope).results,
               &(&1.id == entry.id)
             )
    end
  end
end
