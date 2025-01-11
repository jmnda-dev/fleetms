defmodule FleetmsWeb.PageController do
  require Ash.Query
  use FleetmsWeb, :controller
  use AshAuthentication.Phoenix.Controller


  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home)
  end

  def demo_signin(conn, _params) do
    user =
      Fleetms.Accounts.User
      |> Ash.Query.new()
      |> Ash.Query.filter(email == "demo_user@fleetms.com")
      |> Ash.Query.set_context(%{private: %{ash_authentication?: true}})
      |> Ash.read_one!()
      |> Ash.load!(:organization)

    Fleetms.FeatureFlags.enable_all(user.organization)
    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> maybe_put_tenant_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/dashboard")
  end

  defp maybe_put_tenant_in_session(conn, nil), do: conn

  defp maybe_put_tenant_in_session(conn, user) do
    put_session(conn, :tenant, Ash.ToTenant.to_tenant(user.organization, user.organization))
  end
end
