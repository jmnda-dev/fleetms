defmodule FleetmsWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users and resolving the current organization
  (tenant) in LiveViews.

  Tenancy lives in the URL: tenant-scoped routes are nested under `/o/:org_id`,
  where `:org_id` is the organization's opaque `public_id`. The
  `:require_organization` hook resolves that param into a `Fleetms.Scope`
  (assigned as `current_scope`) on mount and on every `handle_params`, so
  switching organizations is just navigation.
  """

  import Phoenix.Component
  import Phoenix.LiveView
  use FleetmsWeb, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {FleetmsWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  # Requires the user to be platform staff (`is_super_admin`) for the tenant-less
  # `/admin` area. Chained after `:live_user_required`, so `current_user` is present.
  def on_mount(:require_platform_admin, _params, _session, socket) do
    if socket.assigns[:current_user] && socket.assigns.current_user.is_super_admin do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You don't have access to the admin area.")
        |> redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  @doc """
  Requires the user to be working within an organization they belong to.

  Loads the user's memberships once (for the org switcher), redirects to org
  creation when they have none, and attaches a `handle_params` hook that resolves
  the `:org_id` param into `current_scope` / `current_organization` on every
  navigation — redirecting to the picker if the slug isn't one of their orgs.
  """
  def on_mount(:require_organization, _params, session, socket) do
    user = socket.assigns.current_user

    memberships =
      user
      |> Ash.load!([user_organizations: [organization: [:member_count]]], actor: user)
      |> Map.get(:user_organizations)

    # Non-staff with no organization go to creation. Platform staff always get the
    # resolve hook (even with no orgs of their own) so they can enter any client's org.
    if memberships == [] and not user.is_super_admin do
      {:halt, redirect(socket, to: ~p"/orgs/new")}
    else
      socket =
        socket
        |> assign(:memberships, memberships)
        |> assign(:organizations, Enum.map(memberships, & &1.organization))
        # The individual a staff member chose to manage (see AdminController). Only
        # takes effect inside the pool; ignored everywhere else.
        |> assign(:pool_acting_as, session["pool_acting_as"])
        |> attach_hook(:resolve_organization, :handle_params, &resolve_organization/3)

      {:cont, socket}
    end
  end

  # Resolves the `:org_id` (public_id) param against the user's memberships.
  defp resolve_organization(%{"org_id" => public_id}, _uri, socket) do
    user = socket.assigns.current_user
    acting_as = user.is_super_admin && socket.assigns[:pool_acting_as]

    case Enum.find(socket.assigns.memberships, &(&1.organization.public_id == public_id)) do
      nil ->
        # Not a member. Platform staff may still enter any org to act on the
        # client's behalf (a staff-access session, marked on the scope).
        if user.is_super_admin do
          enter_as_staff(socket, user, public_id, acting_as)
        else
          socket =
            socket
            |> put_flash(:error, "That organization isn't available to you.")
            |> redirect(to: ~p"/orgs")

          {:halt, socket}
        end

      membership ->
        org = membership.organization

        cond do
          # A suspended organization is closed to its own members (non-payment,
          # abuse, …). Platform staff still get in via the non-member branch above.
          org.status == :suspended and not user.is_super_admin ->
            socket =
              socket
              |> put_flash(
                :error,
                "This organization is suspended. Please contact FleetMS support."
              )
              |> redirect(to: ~p"/orgs")

            {:halt, socket}

          # Staff often own the pool, so they reach it as a member — but if they're
          # managing a specific client, act on that client's behalf, not as owner.
          acting_as && Fleetms.Individuals.pool?(org) ->
            {:cont, enter_managing(socket, user, org, acting_as)}

          true ->
            resolve_member_org(socket, user, org, membership)
        end
    end
  end

  defp resolve_organization(_params, _uri, socket), do: {:cont, socket}

  # Assigns the scope for an ordinary member entering their (active) organization.
  defp resolve_member_org(socket, user, org, membership) do
    remember_organization(user, org)

    # An individual client is a member of the pool — show their own name as
    # the workspace, never the internal pool name.
    scope = Fleetms.Scope.new(user, org, membership.owner?)

    scope =
      if Fleetms.Individuals.pool?(org),
        do: %{scope | workspace_name: individual_workspace_name(user)},
        else: scope

    socket =
      socket
      |> assign(:current_scope, scope)
      |> assign(:current_organization, org)

    {:cont, socket}
  end

  # Platform staff entering a non-member org. We do NOT remember it as their last
  # org (they don't own it), and the scope carries `staff_access?` so the UI shows
  # the impersonation banner. The deliberate entry is audited at the /admin click.
  defp enter_as_staff(socket, user, public_id, acting_as) do
    case Fleetms.Accounts.get_organization_by_public_id(public_id,
           actor: user,
           load: [:member_count]
         ) do
      {:ok, org} ->
        managing = if Fleetms.Individuals.pool?(org), do: acting_as
        {:cont, enter_managing(socket, user, org, managing)}

      _ ->
        socket =
          socket
          |> put_flash(:error, "That organization could not be found.")
          |> redirect(to: ~p"/admin")

        {:halt, socket}
    end
  end

  # Builds a staff-access scope for `org`. When `acting_as` is a client's owner id
  # (managing one individual in the pool), the scope acts on their behalf, so the
  # owner-scope filter narrows everything to that client's fleet; otherwise it's a
  # plain staff view of the whole org.
  defp enter_managing(socket, user, org, acting_as) do
    scope =
      Fleetms.Scope.on_behalf_of(
        Fleetms.Scope.new(user, org, false, true),
        acting_as,
        acting_as && client_name(acting_as, user)
      )

    # Show the managed client's name as the workspace too, not the pool name.
    socket
    |> assign(:current_scope, %{scope | workspace_name: scope.on_behalf_label})
    |> assign(:current_organization, org)
  end

  defp client_name(owner_id, user) do
    case Fleetms.Accounts.get_client_profile_for_owner(owner_id,
           actor: user,
           not_found_error?: false
         ) do
      {:ok, %{contact_name: name}} -> name
      _ -> nil
    end
  end

  # An individual client's own display name (their user profile), for the pool
  # workspace label. Falls back to a neutral label rather than the internal name.
  defp individual_workspace_name(user) do
    case Ash.load(user, [profile: [:first_name, :last_name]], actor: user) do
      {:ok, %{profile: %{first_name: first} = profile}} when is_binary(first) ->
        [first, profile.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

      _ ->
        "My Fleet"
    end
  end

  @doc """
  Where to send a freshly authenticated user: their last-used organization (if
  still a member), else their only organization, else the picker, else creation.
  """
  def post_auth_path(user) do
    case Fleetms.Accounts.list_organizations!(actor: user) do
      [] -> ~p"/orgs/new"
      [only] -> ~p"/o/#{only}"
      orgs -> last_org_path(user, orgs)
    end
  end

  defp last_org_path(%{last_organization_id: id}, orgs) when not is_nil(id) do
    case Enum.find(orgs, &(&1.id == id)) do
      nil -> ~p"/orgs"
      org -> ~p"/o/#{org}"
    end
  end

  defp last_org_path(_user, _orgs), do: ~p"/orgs"

  # Best-effort: only write when the remembered org actually changed.
  defp remember_organization(%{last_organization_id: id}, %{id: id}), do: :ok

  defp remember_organization(user, org) do
    Fleetms.Accounts.set_last_organization(user, %{last_organization_id: org.id}, actor: user)
    :ok
  rescue
    _ -> :ok
  end
end
