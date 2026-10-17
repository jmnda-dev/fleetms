defmodule FleetmsWeb.UserLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Accounts

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org}
  end

  defp add_plain_member(org) do
    user = user_fixture()

    Accounts.add_user_to_organization!(
      %{user_id: user.id, organization_id: org.id},
      authorize?: false
    )

    user
  end

  describe "index" do
    test "lists members and marks the owner", %{conn: conn, org: org, owner: owner} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/users")
      assert html =~ "Users"
      assert html =~ to_string(owner.email)
      assert html =~ "Owner"
      assert html =~ "Add member"
    end

    test "redirects a member without manage/view access", %{conn: conn} do
      # A different org's owner with no membership in this org.
      {_stranger, other_org} = user_with_org_fixture()
      member = add_plain_member(other_org)

      conn = log_in_user(conn, member)
      # This member belongs to other_org; visiting it lists nothing special, but a
      # plain member with no view_users permission is redirected to the dashboard.
      assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/o/#{other_org}/users")
      assert to == "/o/#{other_org.public_id}"
    end
  end

  describe "inviting / adding members" do
    test "invites a new email and records a pending invitation", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/users/new")
      email = "invitee-#{System.unique_integer([:positive])}@example.com"

      view |> form("#member-form", member: %{email: email}) |> render_submit()

      assert render(view) =~ "Invitation sent"
    end

    test "creates a username-only member who shows up in the list", %{conn: conn, org: org} do
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/users/new")
      username = "driver_#{System.unique_integer([:positive])}"

      view |> element("button", "Create with username") |> render_click()

      html =
        view
        |> form("#member-form",
          member: %{
            first_name: "Sam",
            last_name: "Rider",
            username: username,
            password: "password1234",
            password_confirmation: "password1234"
          }
        )
        |> render_submit()

      assert html =~ "Member created"
      assert render(view) =~ "Sam Rider"
      assert render(view) =~ username
    end
  end

  describe "lifecycle" do
    test "suspend then reactivate a member", %{conn: conn, org: org} do
      member = add_plain_member(org)
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/users")

      html = view |> element("button[phx-value-id]", "Suspend") |> render_click()
      assert html =~ "Member suspended"
      assert render(view) =~ "Suspended"

      html = view |> element("button[phx-value-id]", "Reactivate") |> render_click()
      assert html =~ "Member reactivated"
      _ = member
    end

    test "removes a member via the delete modal", %{conn: conn, org: org} do
      member = add_plain_member(org)
      {:ok, view, _html} = live(conn, ~p"/o/#{org}/users/#{member.id}/delete")

      html = view |> element("button", "Remove member") |> render_click()
      assert html =~ "Member removed"
      refute render(view) =~ to_string(member.email)
    end
  end

  describe "edit (roles)" do
    test "assigns a role to a member via the edit modal", %{conn: conn, org: org, owner: owner} do
      member = add_plain_member(org)
      {:ok, role} = Fleetms.Permissions.create_role(%{"name" => "Dispatcher"}, org, owner)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/users/#{member.id}/edit")
      assert render(view) =~ "Dispatcher"

      view
      |> form("#member-edit-form", %{"edit" => %{"role_ids" => [role.id]}})
      |> render_submit()

      assert render(view) =~ "Roles updated"
      # The role now shows on the member row.
      assert render(view) =~ "Dispatcher"
    end
  end

  describe "view" do
    test "shows a member's details in a modal", %{conn: conn, org: org, owner: owner} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/users/#{owner.id}")
      assert html =~ "member-view-modal"
      assert html =~ to_string(owner.email)
    end
  end
end
