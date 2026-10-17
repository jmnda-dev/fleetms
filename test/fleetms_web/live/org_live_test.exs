defmodule FleetmsWeb.OrgLiveTest do
  @moduledoc "The tenant-less workspace picker at /orgs, and its platform-staff shortcut."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  defp super_admin do
    user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})
  end

  test "platform staff see the Platform Admin shortcut on the picker", %{conn: conn} do
    conn = log_in_user(conn, super_admin())
    {:ok, _view, html} = live(conn, ~p"/orgs")

    assert html =~ "Platform Admin"
    assert html =~ "signed in as platform staff"
    assert html =~ ~p"/admin"
  end

  test "a regular user sees no Platform Admin shortcut", %{conn: conn} do
    {user, _org} = user_with_org_fixture()
    conn = log_in_user(conn, user)
    {:ok, _view, html} = live(conn, ~p"/orgs")

    assert html =~ "Choose an organization"
    refute html =~ "Platform Admin"
    refute html =~ "signed in as platform staff"
  end
end
