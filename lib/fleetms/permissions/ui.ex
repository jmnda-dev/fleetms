defmodule Fleetms.Permissions.UI do
  @moduledoc """
  Helpers for rendering permission forms in LiveView.
  """

  @type grouped_permissions :: %{group: String.t(), permissions: [map()]}

  @doc """
  Returns all active permissions grouped by their `group`, sorted alphabetically
  within each group and across groups. Suitable for a permission-assignment form.
  """
  @spec grouped_for_form() :: [grouped_permissions()]
  def grouped_for_form do
    Fleetms.Permissions.Cache.all()
    |> Enum.filter(& &1.active)
    |> Enum.group_by(& &1.group)
    |> Enum.map(fn {group, perms} ->
      %{group: group || "Other", permissions: Enum.sort_by(perms, & &1.label)}
    end)
    |> Enum.sort_by(& &1.group)
  end

  @doc "Set of permission names currently assigned to a role (with `:permissions` loaded)."
  @spec role_permission_names(role :: map()) :: MapSet.t(String.t())
  def role_permission_names(role) do
    role.permissions |> Enum.map(& &1.name) |> MapSet.new()
  end

  @doc "Set of permission IDs currently assigned to a role (with `:permissions` loaded)."
  @spec role_permission_ids(role :: map()) :: MapSet.t(binary())
  def role_permission_ids(role) do
    role.permissions |> Enum.map(& &1.id) |> MapSet.new()
  end

  @doc "Map of permission_name => permission record for fast template lookup."
  @spec permission_map() :: %{String.t() => map()}
  def permission_map do
    Fleetms.Permissions.Cache.all() |> Map.new(fn p -> {p.name, p} end)
  end

  @doc """
  Resolves permission names (from the ETS cache) to their `public.permissions`
  database UUIDs. Used when assigning permissions to a role.
  """
  @spec resolve_db_ids([String.t()]) :: [binary()]
  def resolve_db_ids(names) when is_list(names) do
    require Ash.Query

    Fleetms.Accounts.Permission
    |> Ash.Query.filter(name in ^names)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end
end
