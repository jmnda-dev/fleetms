defmodule Fleetms.Permissions do
  @moduledoc """
  Public API for the permissions system: a policy-generating macro, permission
  lookups, and role/assignment management with user-cache invalidation.

  Tenancy is organization-based. Pass an `Organization` (or its schema string) as
  `tenant` to the management functions below.
  """

  @doc """
  Generates standard CRUD policy blocks for a resource. Call inside a resource's
  `policies do ... end` block.

      policies do
        Fleetms.Permissions.standard_policies(
          :create_vehicle, :view_vehicles, :update_vehicle, :delete_vehicle
        )
      end
  """
  defmacro standard_policies(create_perm, read_perm, update_perm, destroy_perm) do
    quote do
      policy action_type(:create) do
        authorize_if {Fleetms.Permissions.Check, permission: unquote(create_perm)}
      end

      policy action_type(:read) do
        authorize_if {Fleetms.Permissions.Check, permission: unquote(read_perm)}
      end

      policy action_type(:update) do
        authorize_if {Fleetms.Permissions.Check, permission: unquote(update_perm)}
      end

      policy action_type(:destroy) do
        authorize_if {Fleetms.Permissions.Check, permission: unquote(destroy_perm)}
      end
    end
  end

  @doc """
  Policy check helper: authorizes when the actor holds `permission` in the current
  tenant. Import `Fleetms.Permissions` into a resource to use it bare:

      import Fleetms.Permissions

      policy action(:destroy) do
        authorize_if has_permission(:delete_vehicle)
      end
  """
  def has_permission(permission) do
    {Fleetms.Permissions.Check, permission: permission}
  end

  @doc """
  Policy check helper: authorizes when the actor holds *any* of `permissions` in
  the current tenant.

      policy action(:update) do
        authorize_if has_any_permission([:update_vehicle, :manage_fleet_settings])
      end
  """
  def has_any_permission(permissions) when is_list(permissions) do
    {Fleetms.Permissions.Check, permissions: permissions}
  end

  @doc "Check whether a user has a permission in a given organization."
  def user_has_permission?(user, tenant, permission_name) do
    Fleetms.Permissions.UserCache.has_permission?(user.id, tenant, to_string(permission_name))
  end

  @doc "Invalidate cached permissions for a user in an organization."
  def invalidate_user_cache(user_id, tenant) do
    Fleetms.Permissions.UserCache.invalidate(user_id, tenant)
  end

  # --- Role / assignment management ---

  @doc "List roles for an organization (with permissions loaded)."
  def list_roles(tenant, actor) do
    Fleetms.Accounts.list_roles!(tenant: tenant, actor: actor, load: [:permissions])
  end

  @doc "Create a custom role in an organization."
  def create_role(attrs, tenant, actor) do
    attrs = Map.put(attrs, :organization_id, org_id(tenant))
    Fleetms.Accounts.create_role(attrs, tenant: tenant, actor: actor)
  end

  @doc "Replace a role's permissions with the given DB permission IDs."
  def set_role_permissions(role, permission_ids, tenant, actor) do
    Fleetms.Accounts.set_role_permissions(role, %{permission_ids: permission_ids},
      tenant: tenant,
      actor: actor
    )
  end

  @doc "Assign a role to a user, invalidating their permission cache."
  def assign_role(user_id, role_id, tenant, actor) do
    result =
      Fleetms.Accounts.assign_user_role(%{user_id: user_id, role_id: role_id},
        tenant: tenant,
        actor: actor
      )

    with {:ok, _} <- result, do: invalidate_user_cache(user_id, tenant)
    result
  end

  @doc "Revoke a role assignment from a user, invalidating their permission cache."
  def revoke_role(user_role, tenant, actor) do
    result = Fleetms.Accounts.revoke_user_role(user_role, tenant: tenant, actor: actor)
    with {:ok, _} <- result, do: invalidate_user_cache(user_role.user_id, tenant)
    result
  end

  defp org_id(%Fleetms.Accounts.Organization{id: id}), do: id
  defp org_id("org_" <> id), do: id
  defp org_id(id) when is_binary(id), do: id
end
