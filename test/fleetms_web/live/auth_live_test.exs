defmodule FleetmsWeb.AuthLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "sign in page" do
    test "renders the sign-in form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sign-in")
      assert html =~ "Welcome back"
      assert html =~ "Email"
      assert html =~ "Sign in to your account"
    end

    test "does not render a remember_me field", %{conn: conn} do
      # The remember_me strategy isn't wired into the sign_in action, so posting
      # that field makes sign-in fail with NoSuchInput. Keep it out of the form
      # until the full cookie flow is implemented.
      {:ok, _view, html} = live(conn, ~p"/sign-in")
      refute html =~ "remember_me"
    end

    test "toggles between email and username sign-in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sign-in")

      html = view |> element("button", "Sign in with a username instead") |> render_click()
      assert html =~ "Username"
      assert html =~ "Sign in with an email instead"
    end

    test "redirects an already signed-in user away", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/sign-in")
      refute to == ~p"/sign-in"
    end
  end

  describe "other auth pages" do
    test "the register page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/register")
      assert html =~ "Create an account"
      assert html =~ "Confirm password"
    end

    test "validating and submitting the register form does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      params = %{
        "email" => "newbie-#{System.unique_integer([:positive])}@example.com",
        "password" => "password1234",
        "password_confirmation" => "password1234"
      }

      assert view |> form("form", user: params) |> render_change() =~ "Create account"
      # Submitting a valid form sets phx-trigger-action (handing off to the
      # controller); it must not raise.
      assert view |> form("form", user: params) |> render_submit()
    end

    test "the forgot-password page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/forgot-password")
      assert html =~ "Reset your password"
      assert html =~ "Send reset link"
    end

    test "the reset-password page renders with the token from the URL", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/password-reset/sometoken")
      assert html =~ "Create new password"
      assert html =~ ~s(name="user[reset_token]")
      assert html =~ ~s(value="sometoken")
    end
  end
end
