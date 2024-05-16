defmodule FleetmsWeb.UserLive.ProfileTest do
  use FleetmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Fleetms.AccountsFixtures

  defp register_org_and_user(_) do
    user =
      initial_user_fixture()
      |> Ash.load!(:full_name)

    %{admin_user: user}
  end

  describe "User Profile" do
    setup [:register_org_and_user]

    test "redirects user to sign-in page if not logged in", %{conn: conn} do
      result =
        conn
        |> live(~p"/my_profile")
        |> follow_redirect(conn, "/sign-in")

      assert {:ok, _conn} = result
    end

    test "user can access profile page if logged in", %{conn: conn, admin_user: admin_user} do
      {:ok, _settings_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/my_profile")

      assert html =~ "Update Settings"
      assert html =~ "General information"
      assert html =~ "Roles"
    end

    test "redirects to profile update page when the `Update settings` button is clicked", %{
      conn: conn,
      admin_user: admin_user
    } do
      {:ok, settings_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/my_profile")

      settings_live
      |> element("a", "Update Settings")
      |> render_click()

      assert_redirect(settings_live, ~p"/settings")
    end
  end
end
