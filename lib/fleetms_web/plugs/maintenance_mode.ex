defmodule FleetmsWeb.Plugs.MaintenanceMode do
  @moduledoc """
  Serves the styled 503 page for browser requests while the `maintenance_mode`
  feature flag is on. Platform staff (`is_super_admin`) pass through so they can
  keep working and verify the app during the window.

  Runs in the `:browser` pipeline, so it never touches `/health` (own scope) or
  the feature-flags admin UI (`/admin/feature-flags`, its own pipeline) — staff
  can always reach that to switch maintenance back off, and static assets are
  served by `Plug.Static` before the router, so the 503 page still styles.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Fleetms.FeatureFlags.maintenance_mode?() and not staff?(conn) do
      conn
      |> put_status(503)
      |> Phoenix.Controller.put_view(FleetmsWeb.ErrorHTML)
      |> Phoenix.Controller.render("503.html")
      |> halt()
    else
      conn
    end
  end

  defp staff?(%{assigns: %{current_user: %{is_super_admin: true}}}), do: true
  defp staff?(_), do: false
end
