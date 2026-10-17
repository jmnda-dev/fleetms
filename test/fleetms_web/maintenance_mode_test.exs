defmodule FleetmsWeb.MaintenanceModeTest do
  @moduledoc "The maintenance_mode flag serves 503 to everyone but platform staff."
  use FleetmsWeb.ConnCase

  alias Fleetms.FeatureFlags

  test "off (default): the site loads normally", %{conn: conn} do
    FeatureFlags.disable(:maintenance_mode)
    conn = get(conn, "/")
    assert conn.status == 200
  end

  test "on: anonymous visitors get the 503 maintenance page", %{conn: conn} do
    FeatureFlags.enable(:maintenance_mode)
    conn = get(conn, "/")

    assert conn.status == 503
    assert conn.resp_body =~ "maintenance"
  end

  test "on: platform staff pass through", %{conn: conn} do
    FeatureFlags.enable(:maintenance_mode)
    admin = user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})

    conn = conn |> log_in_user(admin) |> get("/")
    assert conn.status == 200
  end
end
