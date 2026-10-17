defmodule FleetmsWeb.ProfileSettingsTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Accounts

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org}
  end

  describe "profile" do
    test "renders and creates a profile on first save", %{conn: conn, org: org, owner: owner} do
      {:ok, view, html} = live(conn, ~p"/o/#{org}/profile")
      assert html =~ "My Profile"
      # No profile yet: falls back to the identifier.
      assert html =~ to_string(owner.email)

      html =
        view
        |> form("#profile-form", profile: %{first_name: "Bonnie", last_name: "Green"})
        |> render_submit()

      assert html =~ "Profile saved"
      assert html =~ "Bonnie Green"

      assert {:ok, profile} = Accounts.get_user_profile(owner.id, actor: owner)
      assert profile.first_name == "Bonnie"
    end

    test "updates an existing profile", %{conn: conn, org: org, owner: owner} do
      Accounts.create_user_profile(%{user_id: owner.id, first_name: "Old"}, actor: owner)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/profile")

      html =
        view
        |> form("#profile-form", profile: %{first_name: "New", phone_number: "123-456-7890"})
        |> render_submit()

      assert html =~ "Profile saved"
      assert html =~ "New"
    end
  end

  describe "settings" do
    test "shows account info", %{conn: conn, org: org, owner: owner} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/settings")
      assert html =~ "Account Settings"
      assert html =~ to_string(owner.email)
      assert html =~ "Change password"
    end

    test "changes the password with the correct current password", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/settings")

      html =
        view
        |> form("#password-form",
          password: %{
            current_password: "password1234",
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        )
        |> render_submit()

      assert html =~ "Password updated"
    end

    test "rejects a wrong current password", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/settings")

      html =
        view
        |> form("#password-form",
          password: %{
            current_password: "wrong-password",
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        )
        |> render_submit()

      refute html =~ "Password updated"
    end
  end
end
