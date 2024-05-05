defmodule FleetmsWeb.UserLive.ListTest do
  use FleetmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Fleetms.AccountsFixtures

  @create_attrs %{
    email: "jackdoe@example.com",
    password: "pasS123@",
    password_confirmation: "pasS123@",
    user_profile: %{first_name: "Jack", last_name: "Doe"},
    roles: [:fleet_manager]
  }
  @update_email_attrs %{
    email: "superadmin@example.com"
  }

  @update_password_attrs %{
    password: "pasS123@_",
    password_confirmation: "pasS123@_"
  }

  @invalid_attrs %{
    email: nil,
    password: nil,
    password_confirmation: nil
  }

  defp create_initial_org_and_user(_) do
    user =
      initial_user_fixture()
      |> Ash.load!(:full_name)

    %{admin_user: user}
  end

  describe "User Listing Page" do
    setup [:create_initial_org_and_user]

    test "lists all users", %{conn: conn, admin_user: admin_user} do
      {:ok, _user_list_live, html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/users")

      assert html =~ "All users"
      assert html =~ admin_user.full_name
    end

    test "User with `fleet_manager`, `technician`, or `driver` role cannot add user", %{
      conn: conn,
      admin_user: admin_user
    } do
      user =
        org_user_fixture(%{
          organization_id: admin_user.organization_id,
          roles: [:fleet_manager, :technician, :driver]
        })

      {:ok, user_list_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users")

      assert html =~ "All users"
      assert html =~ admin_user.full_name
      assert html =~ user.full_name
      refute has_element?(user_list_live, "button", "Add user")

      assert_raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Unauthorized action", fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/users/new")
      end
    end

    test "User with `fleet_manager`, `technician`, or `driver` roles cannot update user", %{
      conn: conn,
      admin_user: admin_user
    } do
      user =
        org_user_fixture(%{
          organization_id: admin_user.organization_id,
          roles: [:fleet_manager, :technician, :driver]
        })

      {:ok, user_list_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users")

      assert html =~ "All users"
      assert html =~ admin_user.full_name
      assert html =~ user.full_name
      refute has_element?(user_list_live, ~s{[href="/users/#{admin_user.id}/edit"]}, "Edit user")

      assert_raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Unauthorized action", fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user}/edit")
      end
    end

    test "User with `viewer` role cannot view users list, add or update a user", %{
      conn: conn,
      admin_user: admin_user
    } do
      user =
        org_user_fixture(%{
          organization_id: admin_user.organization_id,
          roles: [:viewer]
        })

      assert_raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Unauthorized action", fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/users")
      end

      assert_raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Unauthorized action", fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/users/new")
      end

      assert_raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Unauthorized action", fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/users/#{user}/edit")
      end
    end

    test "creates a new user", %{conn: conn, admin_user: admin_user} do
      {:ok, user_list_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/users")

      assert user_list_live |> element("a", "Add user") |> render_click() =~
               "New User"

      assert_patch(user_list_live, ~p"/users/new")

      form_html =
        user_list_live
        |> form("#user_form",
          user: %{@invalid_attrs | email: "some email", password: "some password"}
        )
        |> render_change()

      assert form_html =~ "is required"
      assert form_html =~ "Invalid email format"

      assert form_html =~
               "Invalid password format. Password should be a combination of lowercase and uppercase letters, numbers, and at least one of these characters: @#$-_+"

      assert user_list_live
             |> form("#user_form",
               user: @create_attrs
             )
             |> render_submit()

      assert_patch(user_list_live, ~p"/users")

      html = render(user_list_live)
      assert html =~ "User created successfully"
      assert html =~ "jackdoe@example.com"
      assert html =~ admin_user.full_name
      assert html =~ "fleet_manager"
    end

    test "updates user email in listing", %{conn: conn, admin_user: admin_user} do
      {:ok, user_list_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/users")

      assert user_list_live
             |> element(~s{[href="/users/#{admin_user.id}/edit"]}, "Edit user")
             |> render_click() =~
               "Edit User"

      assert_patch(user_list_live, ~p"/users/#{admin_user}/edit")

      assert user_list_live
             |> form("#user_form",
               user: @invalid_attrs
             )
             |> render_change() =~ "is required"

      form_html =
        user_list_live
        |> form("#user_form",
          user: %{email: "some email"}
        )
        |> render_change()

      assert form_html =~ "Invalid email format"

      assert user_list_live
             |> form("#user_form", user: @update_email_attrs)
             |> render_submit()

      assert_patch(user_list_live, ~p"/users")

      html = render(user_list_live)
      assert html =~ "User updated successfully"
      assert html =~ @update_email_attrs.email
    end

    test "updates user password in listing and user can login with new password", %{
      conn: conn,
      admin_user: admin_user
    } do
      {:ok, user_list_live, _html} =
        conn
        |> log_in_user(admin_user)
        |> live(~p"/users")

      assert user_list_live
             |> element(~s{[href="/users/#{admin_user.id}/edit"]}, "Edit user")
             |> render_click() =~
               "Edit User"

      assert_patch(user_list_live, ~p"/users/#{admin_user}/edit")

      assert user_list_live
             |> form("#user_form",
               user: @invalid_attrs
             )
             |> render_change() =~ "is required"

      form_html =
        user_list_live
        |> form("#user_form",
          user: %{password: "some password"}
        )
        |> render_change()

      assert form_html =~
               "Invalid password format. Password should be a combination of lowercase and uppercase letters, numbers, and at least one of these characters: @#$-_+"

      assert user_list_live
             |> form("#user_form",
               user: Map.put(@update_password_attrs, :email, @update_email_attrs.email)
             )
             |> render_submit()

      assert_patch(user_list_live, ~p"/users")

      html = render(user_list_live)
      assert html =~ "User updated successfully"
      assert html =~ @update_email_attrs.email

      {:ok, sign_in_live, _html} = live(conn, ~p"/sign-in")

      form =
        sign_in_live
        |> form("#sign_in_form",
          user: %{email: @update_email_attrs.email, password: "Hello2theWorld!"}
        )

      conn = submit_form(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Email or password is incorrect"

      form =
        sign_in_live
        |> form("#sign_in_form",
          user: %{email: @update_email_attrs.email, password: @update_password_attrs.password}
        )

      conn = submit_form(form, conn)
      assert redirected_to(conn) == ~p"/"
    end
  end
end
