defmodule FleetmsWeb.AuthFlowTest do
  @moduledoc """
  Exercises the real authentication handoff: the custom LiveViews POST to the
  AshAuthentication controller routes, so these tests hit those endpoints
  directly to confirm the wiring (and the confirmation gate) end to end.
  """
  use FleetmsWeb.ConnCase

  describe "password sign-in" do
    test "a confirmed user is signed in and redirected away from sign-in", %{conn: conn} do
      user = user_fixture(%{password: "password1234"})

      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => to_string(user.email), "password" => "password1234"}
        })

      assert redirected_to(conn) != ~p"/sign-in"
      assert get_session(conn, "user_token") || get_session(conn, :user)
    end

    test "an unconfirmed user is bounced back to sign-in with a confirmation notice",
         %{conn: conn} do
      user = user_fixture(%{password: "password1234", confirmed: false})

      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => to_string(user.email), "password" => "password1234"}
        })

      assert redirected_to(conn) == ~p"/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "confirm"
    end

    test "wrong credentials bounce back to sign-in", %{conn: conn} do
      user = user_fixture(%{password: "password1234"})

      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => to_string(user.email), "password" => "wrong-password"}
        })

      assert redirected_to(conn) == ~p"/sign-in"
    end
  end

  describe "username sign-in" do
    test "a username-only member can sign in", %{conn: conn} do
      {owner, org} = user_with_org_fixture()
      username = "driver_#{System.unique_integer([:positive])}"

      {:ok, _user} =
        Fleetms.Membership.create_member_with_username(
          %{
            username: username,
            password: "password1234",
            password_confirmation: "password1234",
            profile: %{first_name: "Drive"}
          },
          org,
          owner
        )

      conn =
        post(conn, ~p"/auth/user/username_password/sign_in", %{
          "user" => %{"username" => username, "password" => "password1234"}
        })

      assert redirected_to(conn) != ~p"/sign-in"
    end
  end

  describe "registration" do
    test "creates an account but does not sign in until confirmed", %{conn: conn} do
      email = "newbie-#{System.unique_integer([:positive])}@example.com"

      conn =
        post(conn, ~p"/auth/user/password/register", %{
          "user" => %{
            "email" => email,
            "password" => "password1234",
            "password_confirmation" => "password1234"
          }
        })

      assert redirected_to(conn) == ~p"/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "confirm"

      # The account exists but is unconfirmed.
      assert {:ok, user} = Fleetms.Accounts.get_user_by_email(email, authorize?: false)
      assert is_nil(user.confirmed_at)
    end
  end

  describe "sign out" do
    test "DELETE /sign-out clears the session and redirects home", %{conn: conn} do
      user = user_fixture(%{password: "password1234"})
      conn = log_in_user(conn, user)

      conn = delete(conn, ~p"/sign-out")

      assert redirected_to(conn) == ~p"/"

      refute get_session(conn, "user") || get_session(conn, :user) ||
               get_session(conn, "user_token")
    end

    test "the Ash-branded GET /sign-out page no longer exists", %{conn: conn} do
      # Only a DELETE route remains; a GET no longer renders Ash's SignOutLive.
      conn = get(conn, "/sign-out")
      assert conn.status == 404
    end
  end
end
