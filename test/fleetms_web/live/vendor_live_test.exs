defmodule FleetmsWeb.VendorLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.MaintenanceFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists vendors and the new action", %{conn: conn, org: org, scope: scope} do
    vendor_fixture(scope, %{name: "Ace Body Shop", contact_name: "Jo"})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/vendors")

    assert html =~ "Vendors"
    assert html =~ "New vendor"
    assert html =~ "Ace Body Shop"
  end

  test "creates a vendor", %{conn: conn, org: org, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/vendors/new")

    view
    |> form("#vendor-form", vendor: %{name: "Northside Tyres", phone: "0123"})
    |> render_submit()

    assert [vendor] = Maintenance.list_vendors!(%{search_query: "northside"}, scope: scope)
    assert vendor.name == "Northside Tyres"
  end

  test "archives a vendor, then restores it from the archived view", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vendor = vendor_fixture(scope, %{name: "Old Supplier"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/vendors")

    view
    |> element(~s|button[phx-click="archive"][phx-value-id="#{vendor.id}"]|)
    |> render_click()

    assert Maintenance.list_vendors!(%{}, scope: scope) == []

    {:ok, archived, html} = live(conn, ~p"/o/#{org}/vendors?archived=1")
    assert html =~ "Archived vendors"
    assert html =~ "Old Supplier"

    archived
    |> element(~s|button[phx-click="restore"][phx-value-id="#{vendor.id}"]|)
    |> render_click()

    assert Enum.any?(Maintenance.list_vendors!(%{}, scope: scope), &(&1.id == vendor.id))
  end
end
