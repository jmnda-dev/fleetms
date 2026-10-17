defmodule FleetmsWeb.FeatureFlagsUITest do
  @moduledoc "The forwarded FunWithFlags admin UI is platform-staff only."
  use FleetmsWeb.ConnCase

  test "signed-out visitors are sent to sign-in", %{conn: conn} do
    conn = get(conn, "/admin/feature-flags")
    assert redirected_to(conn) =~ "/sign-in"
  end

  test "a non-staff user is redirected home", %{conn: conn} do
    {user, _org} = user_with_org_fixture()
    conn = conn |> log_in_user(user) |> get("/admin/feature-flags")
    assert redirected_to(conn) == "/"
  end

  test "platform staff reach the flags UI", %{conn: conn} do
    admin = user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})
    conn = conn |> log_in_user(admin) |> get("/admin/feature-flags")

    # Past the gate: the UI's root redirects to its /flags index.
    assert redirected_to(conn) =~ "feature-flags/flags"
  end
end
