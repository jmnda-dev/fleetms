defmodule FleetmsWeb.AdminPagesTest do
  @moduledoc "Smoke tests for the Roles & Permissions and User Roles admin pages."
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org}
  end

  describe "roles & permissions" do
    test "renders and can create a role", %{conn: conn, org: org} do
      {:ok, view, html} = live(conn, ~p"/o/#{org}/roles")
      assert html =~ "Create a role"
      # System roles seeded on org creation are listed.
      assert html =~ "Administrator"

      html =
        view
        |> form("#role-form", role: %{name: "Dispatcher", description: "Handles dispatch"})
        |> render_submit()

      assert html =~ "Role created"
      assert html =~ "Dispatcher"
    end

    test "can open a role's permission editor", %{conn: conn, org: org, owner: owner} do
      system_role = Enum.find(Fleetms.Permissions.list_roles(org, owner), & &1.is_system)
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/roles")

      html =
        view
        |> element(~s|button[phx-value-id="#{system_role.id}"]|, "Edit permissions")
        |> render_click()

      assert html =~ "Permissions for"
      assert html =~ "Save permissions"
    end
  end

  describe "user roles" do
    test "lists members and assigns a role", %{conn: conn, org: org, owner: owner} do
      {:ok, role} = Fleetms.Permissions.create_role(%{"name" => "Dispatcher"}, org, owner)

      {:ok, view, html} = live(conn, ~p"/o/#{org}/user-roles")
      assert html =~ to_string(owner.email)

      html =
        view
        |> form("#assign-form-#{owner.id}", %{"user_id" => owner.id, "role_id" => role.id})
        |> render_submit()

      assert html =~ "Role assigned"
      assert html =~ "Dispatcher"
    end
  end
end
