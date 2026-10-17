defmodule FleetmsWeb.GlobalSearchTest do
  @moduledoc "The ⌘K palette renders in the org shell and surfaces matching records."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures

  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "the palette and its opener are present on an org page", %{conn: conn, org: org} do
    {:ok, _view, html} = live(conn, ~p"/o/#{org}/vehicles")

    assert html =~ "global-search-overlay"
    assert html =~ "data-cmdk-open"
    assert html =~ "Start typing to search across your fleet."
  end

  test "typing a query surfaces a matching vehicle", %{conn: conn, org: org, scope: scope} do
    vehicle_fixture(scope, %{name: "Bulldozer 7"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles")

    html =
      view
      |> element("#global-search-overlay form")
      |> render_change(%{q: "Bulldozer"})

    assert html =~ "Bulldozer 7"
    assert html =~ "Vehicles"
  end

  test "a non-matching query shows the no-results message", %{conn: conn, org: org} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles")

    html =
      view
      |> element("#global-search-overlay form")
      |> render_change(%{q: "zzzznope"})

    assert html =~ "No matches for"
  end
end
