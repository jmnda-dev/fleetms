defmodule Fleetms.Membership do
  @moduledoc """
  Public API for managing who belongs to an organization: listing members,
  inviting/adding them, provisioning username-only accounts, and suspending or
  removing them.

  This is the authoritative authorization gate for user management. Membership
  data spans the public schema (`User`, `UserProfile`, `UserOrganization`,
  `Invitation`) and the tenant schema (`UserRole`), so enforcement is centralized
  here rather than on the resources: every mutating function checks the actor's
  `manage_users` permission (organization owners bypass) before performing the
  underlying writes with `authorize?: false`.

  Key rules:

    * **Portability is earned by email.** Existing accounts are added by email
      only (a verified, global identity). Username-only accounts are never
      discoverable or auto-added to other organizations.
    * **Owners are protected.** The last owner of an organization cannot be
      suspended, removed, or have ownership stripped.
  """
  require Ash.Query

  alias Fleetms.Accounts
  alias Fleetms.Accounts.{Organization, User, UserOrganization}

  @type org :: Organization.t() | String.t()
  @type actor :: User.t()

  # --- Reads ---

  @doc """
  Lists an organization's members (active and suspended), with each member's user
  and profile loaded. Requires `view_users` (owners bypass).
  """
  @spec list_members(org(), actor()) :: {:ok, [UserOrganization.t()]} | {:error, term()}
  def list_members(org, actor) do
    with :ok <- authorize(actor, org, :view_users) do
      memberships =
        UserOrganization
        |> Ash.Query.filter(organization_id == ^org_id(org))
        |> Ash.Query.load(user: [:profile])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!(authorize?: false)

      {:ok, memberships}
    end
  end

  # --- Adding / inviting ---

  @doc """
  Invites someone to the organization by email.

    * If an account already exists for the email, they are added immediately as an
      active member (`{:ok, :added, membership}`).
    * Otherwise an invitation email is sent and a pending invitation is recorded
      (`{:ok, :invited, invitation}`).

  `attrs` requires `:email` and optionally `:role_id` (a tenant role to assign).
  """
  @spec invite_member(map(), org(), actor()) ::
          {:ok, :added, UserOrganization.t()}
          | {:ok, :invited, Fleetms.Accounts.Invitation.t()}
          | {:error, term()}
  def invite_member(attrs, org, actor) do
    with :ok <- authorize(actor, org, :manage_users) do
      email = Map.fetch!(attrs, :email)
      role_id = Map.get(attrs, :role_id)

      case Accounts.get_user_by_email(email, authorize?: false, not_found_error?: false) do
        {:ok, %User{} = user} ->
          add_existing_user(user, role_id, org)

        {:ok, nil} ->
          send_invitation(email, role_id, org, actor)
      end
    end
  end

  @doc """
  Creates a username-only account (no email) and adds it to the organization as an
  active member. For people without email — they sign in with the username and the
  password the admin sets.

  `attrs` requires `:username`, `:password`, `:password_confirmation`, `:profile`
  (a map with at least `:first_name`) and optionally `:role_id`.
  """
  @spec create_member_with_username(map(), org(), actor()) ::
          {:ok, User.t()} | {:error, term()}
  def create_member_with_username(attrs, org, actor) do
    with :ok <- authorize(actor, org, :manage_users) do
      Ash.transaction([User, UserOrganization], fn ->
        user =
          Accounts.create_member_with_username!(
            Map.take(attrs, [:username, :password, :password_confirmation, :profile]),
            authorize?: false
          )

        add_member!(user.id, org)
        maybe_assign_role(user.id, attrs[:role_id], org)
        user
      end)
    end
  end

  @doc """
  Accepts an invitation by its plain token, creating the invitee's account
  (`profile` + password) and their active membership. Runs without an actor — the
  token is the authorization.

  `attrs` requires `:password`, `:password_confirmation`, `:profile`.
  """
  @spec accept_invitation(String.t(), map()) :: {:ok, User.t()} | {:error, term()}
  def accept_invitation(token, attrs) do
    case Accounts.get_invitation_by_token(token, authorize?: false) do
      {:ok, invitation} ->
        Ash.transaction([User, UserOrganization], fn ->
          user =
            Accounts.register_via_invitation!(
              Map.merge(Map.take(attrs, [:password, :password_confirmation, :profile]), %{
                email: invitation.email
              }),
              authorize?: false
            )

          add_member!(user.id, invitation.organization_id)
          maybe_assign_role(user.id, invitation.role_id, invitation.organization_id)
          Accounts.accept_invitation!(invitation, authorize?: false)
          user
        end)

      {:error, _} = error ->
        error
    end
  end

  @doc "Revokes a pending invitation. Requires `manage_users`."
  def revoke_invitation(invitation, org, actor) do
    with :ok <- authorize(actor, org, :manage_users) do
      Accounts.revoke_invitation(invitation, authorize?: false)
    end
  end

  # --- Suspend / reactivate / remove ---

  @doc "Suspends a member's access. Requires `manage_users`; protects the last owner and self."
  def suspend_member(%UserOrganization{} = membership, org, actor) do
    with :ok <- authorize(actor, org, :manage_users),
         :ok <- refute_self(membership, actor, "suspend yourself"),
         :ok <- refute_last_owner(membership, org, "suspend the last owner") do
      Accounts.suspend_membership(membership, authorize?: false)
    end
  end

  @doc "Restores a suspended member's access. Requires `manage_users`."
  def reactivate_member(%UserOrganization{} = membership, org, actor) do
    with :ok <- authorize(actor, org, :manage_users) do
      Accounts.reactivate_membership(membership, authorize?: false)
    end
  end

  @doc """
  Removes a member from the organization — destroys the membership and their
  tenant role assignments. Requires `manage_users`; protects the last owner and
  self. The global user account is untouched (they may belong to other orgs).
  """
  def remove_member(%UserOrganization{} = membership, org, actor) do
    with :ok <- authorize(actor, org, :manage_users),
         :ok <- refute_self(membership, actor, "remove yourself"),
         :ok <- refute_last_owner(membership, org, "remove the last owner") do
      Ash.transaction([UserOrganization, Fleetms.Accounts.UserRole], fn ->
        revoke_all_roles(membership.user_id, org, actor)
        Accounts.remove_membership!(membership, authorize?: false)
        :ok
      end)
    end
  end

  # --- Internal ---

  defp add_existing_user(%User{} = user, role_id, org) do
    result =
      Ash.transaction([User, UserOrganization], fn ->
        membership = add_member!(user.id, org)
        maybe_assign_role(user.id, role_id, org)
        membership
      end)

    case result do
      {:ok, membership} -> {:ok, :added, membership}
      {:error, _} = error -> error
    end
  end

  defp send_invitation(email, role_id, org, actor) do
    org_struct = organization!(org)

    case Accounts.create_invitation(
           %{
             email: email,
             organization_id: org_struct.id,
             role_id: role_id,
             invited_by_id: actor.id,
             organization_name: org_struct.name
           },
           authorize?: false
         ) do
      {:ok, invitation} -> {:ok, :invited, invitation}
      {:error, _} = error -> error
    end
  end

  defp add_member!(user_id, org) do
    Accounts.add_user_to_organization!(
      %{user_id: user_id, organization_id: org_id(org), owner?: false, status: :active},
      authorize?: false
    )
  end

  # Assigns the member's initial role as part of an already-authorized member-
  # creation flow (invite/accept/username creation), so — like `add_member!` — it
  # bypasses the standalone `:assign_user_roles` policy: the caller's `manage_users`
  # gate (or the invitation token) is the authorization. Assigning with the acting
  # user as actor was the bug — an invitee, or an admin without `assign_user_roles`,
  # would be silently denied and the role dropped.
  defp maybe_assign_role(_user_id, nil, _org), do: :ok

  defp maybe_assign_role(user_id, role_id, org) do
    org_struct = organization!(org)

    Accounts.assign_user_role!(%{user_id: user_id, role_id: role_id},
      tenant: org_struct,
      authorize?: false
    )

    Fleetms.Permissions.invalidate_user_cache(user_id, org_struct)
    :ok
  end

  defp revoke_all_roles(user_id, org, actor) do
    org_struct = organization!(org)

    Fleetms.Accounts.UserRole
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read!(authorize?: false, tenant: org_struct)
    |> Enum.each(&Fleetms.Permissions.revoke_role(&1, org_struct, actor))
  end

  defp authorize(%User{} = actor, org, permission) do
    if Fleetms.Permissions.user_has_permission?(actor, organization!(org), permission) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp authorize(_actor, _org, _permission), do: {:error, :forbidden}

  defp refute_self(%UserOrganization{user_id: user_id}, %User{id: actor_id}, what) do
    if user_id == actor_id, do: {:error, {:cannot, what}}, else: :ok
  end

  defp refute_last_owner(%UserOrganization{owner?: false}, _org, _what), do: :ok

  defp refute_last_owner(%UserOrganization{owner?: true}, org, what) do
    owner_count =
      UserOrganization
      |> Ash.Query.filter(organization_id == ^org_id(org) and owner? == true)
      |> Ash.count!(authorize?: false)

    if owner_count <= 1, do: {:error, {:cannot, what}}, else: :ok
  end

  defp organization!(%Organization{} = org), do: org
  defp organization!(org) when is_binary(org), do: Accounts.get_organization!(org_id(org))

  defp org_id(%Organization{id: id}), do: id
  defp org_id("org_" <> id), do: id
  defp org_id(id) when is_binary(id), do: id
end
