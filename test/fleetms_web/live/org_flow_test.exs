defmodule FleetmsWeb.OrgFlowTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "user without an organization" do
    setup :register_and_log_in_user

    test "GET / shows the landing page with a link into onboarding", %{conn: conn} do
      response = html_response(get(conn, ~p"/"), 200)
      assert response =~ "Go to dashboard"
      assert response =~ ~p"/orgs/new"
    end

    test "the org creation page renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/orgs/new")
      assert html =~ "Create your organization"
    end

    test "tenant-scoped routes redirect to org creation", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/orgs/new"}}} = live(conn, ~p"/o/anything")
    end
  end

  describe "user with an organization" do
    setup :register_and_log_in_user

    setup %{user: user} do
      %{org: organization_fixture(user)}
    end

    test "GET / shows the landing page with a link into the organization",
         %{conn: conn, org: org} do
      response = html_response(get(conn, ~p"/"), 200)
      assert response =~ "Go to dashboard"
      assert response =~ "/o/#{org.public_id}"
    end

    test "the dashboard renders within the organization", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}")
      assert html =~ org.name
    end

    test "an organization the user does not belong to redirects to the picker",
         %{conn: conn} do
      assert {:error, {:redirect, %{to: "/orgs"}}} = live(conn, ~p"/o/notmyorg00000")
    end
  end

  describe "account type" do
    setup :register_and_log_in_user

    test "creating an individual organization tailors the sidebar", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, ~p"/orgs/new")
      assert html =~ "Just me"
      assert html =~ "A business"

      view
      |> form("form", organization: %{name: "My Cars", account_type: "individual"})
      |> render_submit()

      org = Fleetms.Accounts.list_organizations!(actor: user) |> List.first()
      assert org.account_type == :individual

      # An individual fleet hides members/roles/administration.
      {:ok, _dash, dash_html} = live(conn, ~p"/o/#{org}")
      refute dash_html =~ "Administration"
      assert dash_html =~ "Vehicles"
    end

    test "a business organization keeps administration in the sidebar", %{conn: conn, user: user} do
      org = organization_fixture(user, "Acme")

      {:ok, _dash, html} = live(conn, ~p"/o/#{org}")
      assert org.account_type == :business
      assert html =~ "Administration"
    end
  end

  describe "tenant isolation" do
    test "roles created in one organization are not visible from another" do
      owner_a = user_fixture()
      owner_b = user_fixture()
      org_a = organization_fixture(owner_a, "Org A")
      org_b = organization_fixture(owner_b, "Org B")

      {:ok, _role} =
        Fleetms.Permissions.create_role(%{"name" => "Dispatcher A"}, org_a, owner_a)

      names_a = org_a |> Fleetms.Permissions.list_roles(owner_a) |> Enum.map(& &1.name)
      names_b = org_b |> Fleetms.Permissions.list_roles(owner_b) |> Enum.map(& &1.name)

      assert "Dispatcher A" in names_a
      refute "Dispatcher A" in names_b
    end
  end
end
