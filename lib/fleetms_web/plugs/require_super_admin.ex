defmodule FleetmsWeb.Plugs.RequireSuperAdmin do
  @moduledoc """
  Restricts a controller/forwarded route to platform staff (`is_super_admin`).
  Used for the feature-flags admin UI. Relies on `plug :load_from_session` having
  assigned `current_user`; signed-out requests go to sign-in, non-staff to home.
  """
  import Plug.Conn
  import Phoenix.Controller
  use FleetmsWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil -> conn |> redirect(to: ~p"/sign-in") |> halt()
      %{is_super_admin: true} -> conn
      _ -> conn |> redirect(to: ~p"/") |> halt()
    end
  end
end
