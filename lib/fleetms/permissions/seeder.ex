defmodule Fleetms.Permissions.Seeder do
  @moduledoc """
  Seeds and maintains the default system roles for organizations. System roles
  have `is_system: true` and cannot be deleted or renamed by org users.

  Their permission grants are *derived* from a filter over the current permission
  set (e.g. Administrator = every permission), so they must be re-synced whenever
  new permissions are introduced — otherwise an Administrator in an org created
  before a feature shipped would silently lack that feature's permissions.
  `sync_all_system_roles!/0` runs on boot (after `Permissions.Sync`) to keep every
  org's system roles current.
  """
  require Logger
  require Ash.Query

  alias Fleetms.Accounts.{Organization, Role}

  @system_roles [
    %{
      name: "Administrator",
      description: "Full access to all features.",
      permission_filter: :all
    },
    %{
      name: "Read Only",
      description: "View-only access across all modules.",
      permission_filter: {:name_pattern, "view_"}
    },
    %{
      name: "Client",
      description:
        "For managed-service clients: view their own fleet and raise issues. Org administration and the shared maintenance catalog are handled by platform staff, so they are not visible.",
      # Only the operational modules a client cares about — deliberately NOT the
      # org admin (users/roles), inventory, vendors or the shared catalog, so those
      # pages and their sidebar links don't appear for a client. Add to this list
      # to expose more to clients.
      permission_filter:
        {:permissions,
         [
           :view_vehicles,
           :view_assignments,
           :view_renewals,
           :view_issues,
           :create_issue,
           :view_work_orders,
           :view_inspections,
           :view_fuel_entries,
           :view_service_reminders,
           :view_comments
         ]}
    }
  ]

  @doc "Seeds the system roles for a freshly created organization."
  @spec seed_for_org!(org :: map()) :: :ok
  def seed_for_org!(org), do: sync_for_org!(org)

  @doc """
  Re-syncs the system roles for every organization to the current permission set.
  Idempotent; safe to run on every boot. Tolerant of individual orgs failing so
  one bad tenant doesn't block the rest.
  """
  @spec sync_all_system_roles!() :: :ok
  def sync_all_system_roles! do
    orgs = Ash.read!(Organization, authorize?: false)

    Enum.each(orgs, fn org ->
      try do
        sync_for_org!(org)
      rescue
        error ->
          Logger.error(
            "[Permissions.Seeder] Failed to sync system roles for org #{org.id}: " <>
              Exception.message(error)
          )
      end
    end)

    Logger.info("[Permissions.Seeder] Synced system roles for #{length(orgs)} organization(s).")
    :ok
  end

  @doc """
  Ensures each system role exists for `org` and grants exactly the permissions its
  filter currently selects. Creates missing roles and updates existing ones.
  """
  @spec sync_for_org!(org :: map()) :: :ok
  def sync_for_org!(org) do
    all_permissions = Fleetms.Permissions.Cache.all()

    Enum.each(@system_roles, fn role_def ->
      permission_ids =
        all_permissions
        |> filter_permissions(role_def.permission_filter)
        |> Enum.map(& &1.name)
        |> Fleetms.Permissions.UI.resolve_db_ids()

      role_def
      |> find_or_create_system_role!(org)
      |> Ash.Changeset.for_update(:set_permissions, %{permission_ids: permission_ids})
      |> Ash.update!(authorize?: false, tenant: org)
    end)

    :ok
  end

  defp find_or_create_system_role!(role_def, org) do
    existing =
      Role
      |> Ash.Query.filter(name == ^role_def.name and is_system == true)
      |> Ash.read_one!(authorize?: false, tenant: org)

    existing || create_system_role!(role_def, org)
  end

  defp create_system_role!(role_def, org) do
    Role
    |> Ash.Changeset.for_create(:seed_system_role, %{
      name: role_def.name,
      description: role_def.description,
      organization_id: org.id
    })
    |> Ash.create!(authorize?: false, tenant: org)
  end

  defp filter_permissions(all, :all), do: all

  # Union of several filters: a permission is kept if any sub-filter selects it.
  defp filter_permissions(all, {:any, filters}) do
    Enum.filter(all, fn p ->
      Enum.any?(filters, fn f -> p in filter_permissions([p], f) end)
    end)
  end

  defp filter_permissions(all, {:groups, groups}),
    do: Enum.filter(all, fn p -> p.group in groups end)

  defp filter_permissions(all, {:permissions, names}) do
    name_strings = Enum.map(names, &to_string/1)
    Enum.filter(all, fn p -> p.name in name_strings end)
  end

  defp filter_permissions(all, {:name_pattern, prefix}),
    do: Enum.filter(all, fn p -> String.starts_with?(p.name, prefix) end)
end
