defmodule Fleetms.Permissions.Manifest do
  @moduledoc """
  Collects all permissions declared via the Permissions DSL from every resource in
  every configured Ash Domain.

  Returns a flat list of maps suitable for DB sync and ETS caching. Multi-action
  permissions are expanded into one entry per action, all sharing the same `name`.
  """

  @type permission_entry :: %{
          name: String.t(),
          label: String.t(),
          description: String.t() | nil,
          group: String.t(),
          resource_module: String.t(),
          action_name: String.t(),
          active: boolean()
        }

  @spec all() :: [permission_entry()]
  def all do
    domains()
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.uniq()
    |> Enum.filter(&permission_extension?/1)
    |> Enum.flat_map(&permissions_for_resource/1)
    |> dedupe_by_name_action()
    |> validate_name_consistency!()
  end

  defp domains do
    Application.get_env(:fleetms, :ash_domains, [])
  end

  defp permission_extension?(resource) do
    Fleetms.Permissions.Dsl in Spark.extensions(resource)
  rescue
    _ -> false
  end

  defp permissions_for_resource(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:permissions])
    |> Enum.flat_map(fn perm ->
      perm.action
      |> List.wrap()
      |> Enum.map(fn action ->
        %{
          name: to_string(perm.name),
          label: perm.label,
          description: perm.description,
          group: perm.group || derive_group(resource),
          resource_module: to_string(resource),
          action_name: to_string(action),
          active: true
        }
      end)
    end)
  end

  # Auto-derive a UI group from the resource module name, e.g.
  # Fleetms.Fleet.Vehicle -> "Fleet".
  defp derive_group(resource) do
    resource
    |> Module.split()
    |> Enum.drop(1)
    |> Enum.drop(-1)
    |> Enum.join(" ")
    |> case do
      "" -> "General"
      g -> g
    end
  end

  # A multi-action permission produces several rows that collapse to one DB row
  # (keyed on name). Keep one entry per {name, action_name}.
  defp dedupe_by_name_action(permissions) do
    permissions
    |> Enum.uniq_by(fn p -> {p.name, p.action_name} end)
  end

  # A permission name must map to a single label/group across all its actions and
  # must not be reused for unrelated permissions on different resources.
  defp validate_name_consistency!(permissions) do
    permissions
    |> Enum.group_by(& &1.name)
    |> Enum.each(fn {name, entries} ->
      resources = entries |> Enum.map(& &1.resource_module) |> Enum.uniq()

      if length(resources) > 1 do
        raise """
        Permission name "#{name}" is declared on more than one resource: \
        #{Enum.join(resources, ", ")}.

        Permission names must be globally unique across resources.
        """
      end
    end)

    permissions
  end
end
