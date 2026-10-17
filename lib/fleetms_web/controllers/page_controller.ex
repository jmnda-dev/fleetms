defmodule FleetmsWeb.PageController do
  use FleetmsWeb, :controller

  def home(conn, _params) do
    # Always show the landing page (so the logo can bring you here). When signed in,
    # the page swaps its "Sign in" call to action for a link into the app.
    dashboard_path =
      case conn.assigns[:current_user] do
        nil -> nil
        user -> FleetmsWeb.LiveUserAuth.post_auth_path(user)
      end

    render(conn, :home, dashboard_path: dashboard_path)
  end
end
