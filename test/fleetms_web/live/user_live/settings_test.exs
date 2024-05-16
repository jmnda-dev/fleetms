defmodule FleetmsWeb.UserLive.SettingsTest do
  use FleetmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Fleetms.AccountsFixtures
  alias Fleetms.Accounts.UserProfile

  @org_user_create_attrs %{
    email: "johndoe@example.com",
    password: "pasS123@",
    password_confirmation: "pasS123@",
    user_profile: %{first_name: "John", last_name: "Doe"},
    roles: [:fleet_manager, :technician, :driver, :viewer]
  }

  @update_attrs %{
    first_name: "OneManda",
    other_name: "Manda",
    date_of_birth: "2010-11-02",
    phone_number: "0101223344",
    address: "123 addr",
    city: "Lusaka",
    state: "Lusaka"
  }

  @invalid_profile_attrs %{
    first_name: nil
  }

  defp register_org_and_user(_) do
    user =
      initial_user_fixture()
      |> Ash.load!(:full_name)

    %{admin_user: user}
  end

  describe "User Settings" do
    setup [:register_org_and_user]

    test "redirects user to sign-in page if not logged in", %{conn: conn} do
      result =
        conn
        |> live(~p"/settings")
        |> follow_redirect(conn, "/sign-in")

      assert {:ok, _conn} = result
    end

    test "user can access settings page if logged in", %{conn: conn, admin_user: admin_user} do
      {:ok, _settings_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/settings")

      assert html =~ "User settings"
      assert html =~ "Change picture"
      assert html =~ "General information"
    end

    test "user with other roles can access settings page if logged in", %{
      conn: conn,
      admin_user: admin_user
    } do
      new_user =
        org_user_fixture(
          Map.put(@org_user_create_attrs, :organization_id, admin_user.organization_id)
        )

      {:ok, _settings_live, html} =
        conn
        |> log_in_user(new_user)
        |> live(~p"/settings")

      assert html =~ "User settings"
      assert html =~ "Change picture"
      assert html =~ "General information"
    end

    test "user can update profile information", %{conn: conn, admin_user: admin_user} do
      %UserProfile{} = old_profile = admin_user.user_profile

      {:ok, settings_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/settings")

      assert settings_live
             |> form("#user_profile_form", user_profile: @invalid_profile_attrs)
             |> render_change() =~ "is required"

      assert settings_live
             |> form("#user_profile_form", user_profile: @update_attrs)
             |> render_submit()

      flash = assert_redirect(settings_live, ~p"/settings", 200)

      assert flash["info"] =~ "Profile information was updated successfully"

      {:ok, _settings_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/settings")

      assert html =~ "#{@update_attrs.first_name} #{old_profile.last_name}"
      assert html =~ @update_attrs.date_of_birth
      assert html =~ @update_attrs.phone_number
      assert html =~ @update_attrs.address
      assert html =~ @update_attrs.city
      assert html =~ @update_attrs.state
    end

    # TODO: Write test for profile photo upload
  end
end
