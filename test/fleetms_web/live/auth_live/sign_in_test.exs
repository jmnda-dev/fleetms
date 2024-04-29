defmodule FleetmsWeb.SignInTest do
  use FleetmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Fleetms.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sign-in")

      assert html =~ "Sign in to platform"
      assert html =~ "Sign in to your account"
      assert html =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(initial_user_fixture())
        |> live(~p"/sign-in")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end
  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      password = "f1289aBcd!"
      user = initial_user_fixture(%{password: password, password_confirmation: password})

      {:ok, lv, _html} = live(conn, ~p"/sign-in")

      form =
        form(lv, "#sign_in_form", user: %{email: user.email, password: password})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/sign-in")

      form =
        form(lv, "#sign_in_form", user: %{email: "test@email.com", password: "123wer45f6"})

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Email or password is incorrect"

      assert redirected_to(conn) == "/sign-in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sign-in")

      {:ok, _login_live, login_html} =
        lv
        |> element("a", "Create account")
        |> render_click()
        |> follow_redirect(conn, ~p"/sign-up")

      assert login_html =~ "Create a free account"
      assert login_html =~ "Explore Fleetms"
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: _conn
    } do
      # TODO: Write this test when password reset feature is implemented
    end
  end
end
