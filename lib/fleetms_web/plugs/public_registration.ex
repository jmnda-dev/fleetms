defmodule FleetmsWeb.Plugs.PublicRegistration do
  @moduledoc """
  Blocks the public self-service sign-up POST (`/auth/user/password/register`)
  when the `user_registration` feature flag is off. The register page and its
  links are hidden in the UI too; this is the server-side backstop so a direct
  POST can't create an account. Everything else (sign-in, invites, resets) is
  untouched.
  """
  import Plug.Conn
  import Phoenix.Controller
  use FleetmsWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    if registration_attempt?(conn) and not Fleetms.FeatureFlags.user_registration?() do
      conn
      |> put_flash(:error, "Sign-up is currently disabled.")
      |> redirect(to: ~p"/sign-in")
      |> halt()
    else
      conn
    end
  end

  defp registration_attempt?(%{method: "POST", path_info: path_info}) do
    match?(["auth" | _], path_info) and List.last(path_info) == "register"
  end

  defp registration_attempt?(_), do: false
end
