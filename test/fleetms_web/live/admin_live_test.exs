defmodule FleetmsWeb.AdminLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  defp super_admin do
    user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})
  end

  test "the dashboard shows a platform-wide rollup", %{conn: conn} do
    {_u1, _org1} = user_with_org_fixture("Alpha Fleet")
    {_u2, _org2} = user_with_org_fixture("Beta Haulage")

    conn = log_in_user(conn, super_admin())
    {:ok, _view, html} = live(conn, ~p"/admin")

    assert html =~ "Platform Admin"
    assert html =~ "Overview"
    assert html =~ "Organizations"
    assert html =~ "User accounts"
    assert html =~ "Vehicles"
    # Recent signups list surfaces the newest orgs.
    assert html =~ "Alpha Fleet"
    assert html =~ "Beta Haulage"
  end

  test "platform staff see every organization across tenants", %{conn: conn} do
    {_u1, _org1} = user_with_org_fixture("Alpha Fleet")
    {_u2, _org2} = user_with_org_fixture("Beta Haulage")

    conn = log_in_user(conn, super_admin())
    {:ok, _view, html} = live(conn, ~p"/admin/organizations")

    assert html =~ "Organizations"
    # A super-admin has no orgs of their own; the bypass surfaces both anyway.
    assert html =~ "Alpha Fleet"
    assert html =~ "Beta Haulage"
  end

  test "a non-admin user is redirected away from /admin", %{conn: conn} do
    {user, _org} = user_with_org_fixture()
    conn = log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
  end

  test "a signed-out visitor is sent to sign-in", %{conn: conn} do
    assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/admin")
    assert to =~ "/sign-in"
  end

  describe "individual clients list" do
    setup do
      on_exit(fn -> Application.delete_env(:fleetms, :individuals_pool_org_id) end)
      :ok
    end

    test "lists provisioned individuals, not corporate orgs", %{conn: conn} do
      admin = super_admin()
      email = "solo-#{System.unique_integer([:positive])}@example.com"

      {:ok, _} =
        Fleetms.Provisioning.provision_client(
          %{account_type: "individual", client_email: email, contact_name: "Solo Client"},
          admin
        )

      # A corporate org that must NOT show up on the individuals page.
      {_owner, _org} = user_with_org_fixture("Corporate Co")

      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/individuals")

      assert html =~ "Individual Clients"
      assert html =~ email
      assert html =~ "Solo Client"
      refute html =~ "Corporate Co"
    end

    test "a non-admin cannot reach the individuals page", %{conn: conn} do
      {user, _org} = user_with_org_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/individuals")
    end

    test "the page redirects to /admin when individual registration is off", %{conn: conn} do
      Fleetms.FeatureFlags.disable(:individual_registration)
      conn = log_in_user(conn, super_admin())

      assert {:error, {:live_redirect, %{to: "/admin"}}} = live(conn, ~p"/admin/individuals")
    end
  end

  describe "provisioning with the individual flag off" do
    setup do
      Fleetms.FeatureFlags.disable(:individual_registration)
      :ok
    end

    test "the provision form offers no Individual option", %{conn: conn} do
      conn = log_in_user(conn, super_admin())
      {:ok, _view, html} = live(conn, ~p"/admin/provision")

      assert html =~ "Business"
      refute html =~ "Individual (personal fleet)"
    end
  end

  describe "managing an individual" do
    setup do
      on_exit(fn -> Application.delete_env(:fleetms, :individuals_pool_org_id) end)
      :ok
    end

    defp provision_individual(admin, contact) do
      {:ok, result} =
        Fleetms.Provisioning.provision_client(
          %{
            account_type: "individual",
            client_email: "ind-#{System.unique_integer([:positive])}@example.com",
            contact_name: contact
          },
          admin
        )

      result
    end

    test "entering sets the session and drops staff into the pool", %{conn: conn} do
      admin = super_admin()
      result = provision_individual(admin, "Zed Client")
      pool = Fleetms.Individuals.find_pool()

      conn = log_in_user(conn, admin)
      conn = get(conn, ~p"/admin/individuals/#{result.client_user.id}/enter")

      assert redirected_to(conn) == "/o/#{pool.public_id}"
      assert get_session(conn, :pool_acting_as) == result.client_user.id
    end

    test "the managing banner names the client inside the pool", %{conn: conn} do
      admin = super_admin()
      result = provision_individual(admin, "Zed Client")
      pool = Fleetms.Individuals.find_pool()

      conn = log_in_user(conn, admin)
      conn = get(conn, ~p"/admin/individuals/#{result.client_user.id}/enter")
      {:ok, _view, html} = live(conn, ~p"/o/#{pool}")

      assert html =~ "Managing"
      assert html =~ "Zed Client"
    end

    test "a non-admin cannot enter", %{conn: conn} do
      {user, _org} = user_with_org_fixture()
      conn = log_in_user(conn, user)

      conn = get(conn, ~p"/admin/individuals/#{Ecto.UUID.generate()}/enter")
      assert redirected_to(conn) =~ "/sign-in"
    end
  end

  describe "provisioning a client" do
    test "staff can open the provisioning form", %{conn: conn} do
      conn = log_in_user(conn, super_admin())
      {:ok, _view, html} = live(conn, ~p"/admin/provision")

      assert html =~ "Provision a client"
      assert html =~ "KYC details"
    end

    test "a non-admin cannot reach provisioning", %{conn: conn} do
      {user, _org} = user_with_org_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/provision")
    end

    test "submitting the form provisions a client and returns to the list", %{conn: conn} do
      conn = log_in_user(conn, super_admin())
      {:ok, view, _html} = live(conn, ~p"/admin/provision")

      email = "prospect-#{System.unique_integer([:positive])}@example.com"

      view
      |> form("#provision-form",
        provision: %{
          name: "Fresh Client Co",
          account_type: "business",
          client_email: email,
          contact_name: "Sam Contact"
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/admin/organizations")

      # The org and its KYC profile now exist.
      [org] =
        Fleetms.Accounts.list_organizations!(authorize?: false)
        |> Enum.filter(&(&1.name == "Fresh Client Co"))

      profile = Fleetms.Accounts.get_client_profile!(org.id, authorize?: false)
      assert profile.contact_name == "Sam Contact"
    end

    test "submitting an individual provisions them into the pool", %{conn: conn} do
      on_exit(fn -> Application.delete_env(:fleetms, :individuals_pool_org_id) end)
      conn = log_in_user(conn, super_admin())
      {:ok, view, _html} = live(conn, ~p"/admin/provision")

      email = "individual-#{System.unique_integer([:positive])}@example.com"

      # Individuals need no org name — the form omits it for them.
      view
      |> form("#provision-form",
        provision: %{account_type: "individual", client_email: email, contact_name: "Chanda"}
      )
      |> render_submit()

      assert_redirect(view, ~p"/admin/organizations")

      # An account was created and given an owner-scoped profile in the pool.
      {:ok, client} = Fleetms.Accounts.get_user_by_email(email, authorize?: false)
      profile = Fleetms.Accounts.get_client_profile_for_owner!(client.id, authorize?: false)
      assert profile.contact_name == "Chanda"
    end
  end

  describe "entering an org as staff" do
    test "platform staff can enter a non-member org and see the staff banner", %{conn: conn} do
      {_owner, org} = user_with_org_fixture("Beta Haulage")

      conn = log_in_user(conn, super_admin())
      {:ok, _view, html} = live(conn, ~p"/o/#{org}")

      assert html =~ "as platform staff"
      assert html =~ "Beta Haulage"
      assert html =~ "Exit to admin"
    end

    test "a non-member, non-staff user cannot enter and is bounced", %{conn: conn} do
      {_owner, org} = user_with_org_fixture("Private Co")
      {stranger, _} = user_with_org_fixture("Stranger Co")

      conn = log_in_user(conn, stranger)
      assert {:error, {:redirect, %{to: "/orgs"}}} = live(conn, ~p"/o/#{org}")
    end

    test "entering from the console records an access log and drops into the org", %{conn: conn} do
      {_owner, org} = user_with_org_fixture("Client Co")
      admin = super_admin()

      conn = log_in_user(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin/organizations")

      render_click(view, "enter", %{"id" => org.id})
      assert_redirect(view, ~p"/o/#{org}")

      logs = Fleetms.Accounts.list_platform_access_logs!(actor: admin).results
      assert Enum.any?(logs, &(&1.organization_id == org.id and &1.admin_user_id == admin.id))
    end
  end

  describe "organization detail + lifecycle" do
    test "renders an org's detail page with its figures", %{conn: conn} do
      {_owner, org} = user_with_org_fixture("Detail Co")

      conn = log_in_user(conn, super_admin())
      {:ok, _view, html} = live(conn, ~p"/admin/organizations/#{org.id}")

      assert html =~ "Detail Co"
      assert html =~ "Members"
      assert html =~ "Vehicles"
      assert html =~ "Active"
    end

    test "suspend then reactivate an organization", %{conn: conn} do
      {_owner, org} = user_with_org_fixture("Suspend Co")

      conn = log_in_user(conn, super_admin())
      {:ok, view, _html} = live(conn, ~p"/admin/organizations/#{org.id}")

      render_click(view, "toggle-suspend-form")

      html =
        view
        |> form("form[phx-submit='suspend']", %{"reason" => "Non-payment"})
        |> render_submit()

      assert html =~ "suspended"
      assert Fleetms.Accounts.get_organization!(org.id, authorize?: false).status == :suspended

      html = render_click(view, "reactivate")
      assert html =~ "Active"
      assert Fleetms.Accounts.get_organization!(org.id, authorize?: false).status == :active
    end

    test "a suspended organization blocks its own members", %{conn: conn} do
      {owner, org} = user_with_org_fixture("Blocked Co")

      Fleetms.Accounts.suspend_organization!(org, %{suspension_reason: "test"},
        actor: super_admin()
      )

      conn = log_in_user(conn, owner)
      assert {:error, {:redirect, %{to: "/orgs"}}} = live(conn, ~p"/o/#{org}")
    end
  end

  describe "access log page" do
    test "lists staff access events", %{conn: conn} do
      {_owner, org} = user_with_org_fixture("Logged Co")
      admin = super_admin()
      Fleetms.Accounts.record_platform_access!(%{organization_id: org.id}, actor: admin)

      conn = log_in_user(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/admin/access-log")

      assert html =~ "Access log"
      assert html =~ "Logged Co"
      assert html =~ to_string(admin.email)
    end
  end

  describe "organization search" do
    test "filters the org list by name", %{conn: conn} do
      user_with_org_fixture("Findable Fleet")
      user_with_org_fixture("Other Haulage")

      conn = log_in_user(conn, super_admin())
      {:ok, view, _html} = live(conn, ~p"/admin/organizations")

      html = view |> form("form[phx-change='search']", %{"q" => "Findable"}) |> render_change()
      assert html =~ "Findable Fleet"
      refute html =~ "Other Haulage"
    end
  end
end
