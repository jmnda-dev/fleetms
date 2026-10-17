defmodule FleetmsWeb.DriverLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Drivers
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists drivers and flags an expired licence", %{conn: conn, org: org, scope: scope} do
    Drivers.create_driver!(
      %{
        first_name: "John",
        last_name: "Banda",
        license_number: "DL-1",
        license_expiry: Date.add(Date.utc_today(), -1)
      },
      scope: scope
    )

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/drivers")

    assert html =~ "Drivers"
    assert html =~ "John"
    assert html =~ "DL-1"
    assert html =~ "Expired"
  end

  test "creates a driver through the form", %{conn: conn, org: org, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/drivers/new")

    view
    |> form("#driver-form",
      driver: %{first_name: "Mary", last_name: "Phiri", phone: "0977000000", status: "active"}
    )
    |> render_submit()

    assert [driver] = Drivers.list_drivers!(%{}, scope: scope).results
    assert driver.first_name == "Mary"
    assert driver.last_name == "Phiri"
  end

  test "archives a driver", %{conn: conn, org: org, scope: scope} do
    driver = Drivers.create_driver!(%{first_name: "Temp", last_name: "Driver"}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/drivers")
    render_click(view, "archive", %{"id" => driver.id})

    assert Drivers.list_drivers!(%{}, scope: scope).results == []
  end
end
