defmodule FleetmsWeb.UserRegistrationFlagTest do
  @moduledoc "The user_registration flag gates public self-service sign-up."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.FeatureFlags

  describe "when sign-up is enabled" do
    setup do
      FeatureFlags.enable(:user_registration)
      :ok
    end

    test "the register page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/register")
      assert html =~ "Create an account"
    end

    test "the sign-in page offers a sign-up link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sign-in")
      assert html =~ "Sign up"
    end
  end

  describe "when sign-up is disabled" do
    setup do
      FeatureFlags.disable(:user_registration)
      :ok
    end

    test "the register page redirects to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/register")
    end

    test "a direct register POST is blocked", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/user/password/register", %{
          "user" => %{
            "email" => "blocked-#{System.unique_integer([:positive])}@example.com",
            "password" => "password1234",
            "password_confirmation" => "password1234"
          }
        })

      assert redirected_to(conn) == "/sign-in"
    end

    test "the sign-in page hides the sign-up link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sign-in")
      refute html =~ "Sign up"
    end
  end
end
