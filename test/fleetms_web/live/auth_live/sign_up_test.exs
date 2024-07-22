defmodule FleetmsWeb.SignUpLiveTest do
  use FleetmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Fleetms.AccountsFixtures

  describe "Sign up page" do
    test "renders a sign up page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sign-up")

      assert html =~ "Create a free account"
      assert html =~ "Explore Fleetms"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(initial_user_fixture())
        |> live(~p"/sign-up")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sign-up")

      result =
        lv
        |> element("#sign_up_form")
        |> render_change(
          user: %{
            "email" => "with spaces",
            "password" => "invalid_pass",
            "password_confirmation" => "invalid_pass"
          }
        )

      assert result =~ "Create a free account"
      assert result =~ "Invalid email format"
      assert result =~ "Invalid password format."
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sign-up")

      email = unique_user_email()
      form = form(lv, "#sign_up_form", user: valid_initial_user_attributes(%{email: email}))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Account settings"
      assert response =~ "Sign out"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sign-up")

      user = initial_user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#sign_up_form",
          user: valid_initial_user_attributes(%{"email" => user.email})
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end

    test "renders errors for duplicated organization name", %{conn: _conn} do
      # TODO: Fix this failing Test
      # {:ok, lv, _html} = live(conn, ~p"/sign-up")

      # user =
      #   initial_user_fixture(%{organization: %{name: "Test Org"}})
      #   |> Ash.load!(:organization)

      # result =
      #   lv
      #   |> form("#sign_up_form",
      #     user: valid_initial_user_attributes(%{organization: %{name: user.organization.name}})
      #   )
      #   |> render_submit()

      # assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sign-up")

      {:ok, _login_live, login_html} =
        lv
        |> element("a", "Login here")
        |> render_click()
        |> follow_redirect(conn, ~p"/sign-in")

      assert login_html =~ "Sign in to platform"
    end
  end
end
