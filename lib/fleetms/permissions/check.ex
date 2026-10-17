defmodule Fleetms.Permissions.Check do
  @moduledoc """
  Ash policy check that authorizes when the actor holds a named permission in the
  current tenant (organization).

      policy action(:create) do
        authorize_if {Fleetms.Permissions.Check, permission: :create_vehicle}
      end

  Pass `permissions:` with a list to authorize when the actor holds *any* of them:

      policy action(:read) do
        authorize_if {Fleetms.Permissions.Check, permissions: [:view_vehicles, :audit_logs]}
      end

  Each permission may be an atom or string. Platform super-admins and organization
  owners bypass the check (the latter via `UserCache`). See `Fleetms.Permissions`
  for the `has_permission/1` and `has_any_permission/1` policy helpers.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(options) do
    case permission_names(options) do
      [name] -> "has permission: #{name}"
      names -> "has any permission: #{Enum.join(names, ", ")}"
    end
  end

  @impl true
  def match?(nil, _context, _options), do: false

  def match?(actor, context, options) do
    if super_admin?(actor) do
      true
    else
      tenant = tenant(context)

      options
      |> permission_names()
      |> Enum.any?(&Fleetms.Permissions.UserCache.has_permission?(actor.id, tenant, &1))
    end
  end

  defp permission_names(options) do
    cond do
      names = options[:permissions] -> Enum.map(names, &to_string/1)
      name = options[:permission] -> [to_string(name)]
      true -> []
    end
  end

  defp super_admin?(%{is_super_admin: true}), do: true
  defp super_admin?(_), do: false

  defp tenant(%{subject: %{tenant: tenant}}) when not is_nil(tenant), do: tenant
  defp tenant(_), do: nil
end
