defmodule FleetmsWeb.Plugs.RequireOrganization do
  @moduledoc """
  Controller-side counterpart to the `:require_organization` LiveView hook: resolves the
  `:org_id` path param (an organization's `public_id`) into a `Fleetms.Scope` and assigns
  it as `current_scope`, so plain controllers (e.g. CSV exports) run with the same
  membership check the LiveViews get.

  Relies on `plug :load_from_session` (in the `:browser` pipeline) having assigned
  `current_user`. A signed-out request is sent to sign-in; a request for an organization
  the user doesn't belong to is sent back to the org picker.
  """
  import Plug.Conn
  import Phoenix.Controller
  use FleetmsWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    org_id = conn.path_params["org_id"]

    with false <- is_nil(user),
         membership when not is_nil(membership) <- find_membership(user, org_id) do
      org = membership.organization

      if org.status == :suspended and not user.is_super_admin do
        conn
        |> put_flash(:error, "This organization is suspended. Please contact FleetMS support.")
        |> redirect(to: ~p"/orgs")
        |> halt()
      else
        conn
        |> assign(:current_scope, Fleetms.Scope.new(user, org, membership.owner?))
        |> assign(:current_organization, org)
      end
    else
      true ->
        conn
        |> redirect(to: ~p"/sign-in")
        |> halt()

      _ ->
        conn
        |> put_flash(:error, "That organization isn't available to you.")
        |> redirect(to: ~p"/orgs")
        |> halt()
    end
  end

  defp find_membership(user, public_id) do
    user
    |> Ash.load!([user_organizations: [:organization]], actor: user)
    |> Map.get(:user_organizations)
    |> Enum.find(&(&1.organization.public_id == public_id))
  end
end
