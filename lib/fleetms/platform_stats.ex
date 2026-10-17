defmodule Fleetms.PlatformStats do
  @moduledoc """
  Cross-tenant rollup numbers for the platform-admin console.

  Organizations and users live in the public schema, so those are single
  queries. Vehicles, issues and work orders are tenant-scoped (schema per
  organization), so we fan out over every tenant and sum the per-schema counts.

  All reads run with `authorize?: false`: this module is only ever called from
  the `is_super_admin` admin area, whose route already gates access, and the
  point of the rollup is precisely to see across tenants the way an ordinary
  actor's policies would never allow.

  The fan-out is `O(tenants)` queries per metric. That is fine at our current
  scale (low hundreds of organizations). If tenant counts grow past that, this
  is the first thing to move behind a cached, periodically-refreshed snapshot.
  """

  require Ash.Query

  alias Fleetms.Accounts.Organization
  alias Fleetms.Accounts.User
  alias Fleetms.Maintenance.WorkOrder
  alias Fleetms.VehicleIssues.Issue
  alias Fleetms.VehicleManagement.Vehicle

  @recent_window_days 30
  @recent_signups 5

  @doc """
  Returns a map of platform-wide figures for the admin dashboard.
  """
  def overview do
    all_orgs =
      Organization
      |> Ash.read!(authorize?: false, load: [:member_count])
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    # The individuals pool is internal infrastructure — exclude it from the client
    # organization figures, but still fan out over its schema for resource counts
    # (the vehicles/issues/work orders in it belong to real individual clients).
    organizations = Enum.reject(all_orgs, &Fleetms.Individuals.pool?/1)
    tenants = Enum.map(all_orgs, &Ash.ToTenant.to_tenant(&1, Organization))
    cutoff = DateTime.add(DateTime.utc_now(), -@recent_window_days, :day)

    %{
      organizations: length(organizations),
      businesses: Enum.count(organizations, &(&1.account_type == :business)),
      individuals: Enum.count(organizations, &(&1.account_type == :individual)),
      new_organizations:
        Enum.count(organizations, &(DateTime.compare(&1.inserted_at, cutoff) == :gt)),
      users: Ash.count!(User, authorize?: false),
      vehicles: sum_over_tenants(tenants, &count_vehicles/1),
      open_issues: sum_over_tenants(tenants, &count_open_issues/1),
      open_work_orders: sum_over_tenants(tenants, &count_open_work_orders/1),
      recent_organizations: Enum.take(organizations, @recent_signups)
    }
  end

  @doc """
  Per-organization resource counts for the admin detail page. Reads the org's own
  tenant schema (super-admin context); a missing/mid-migration schema yields zeros.
  """
  def for_organization(%Organization{} = org) do
    tenant = Ash.ToTenant.to_tenant(org, Organization)

    %{
      vehicles: count_vehicles(tenant),
      open_issues: count_open_issues(tenant),
      open_work_orders: count_open_work_orders(tenant)
    }
  end

  defp sum_over_tenants(tenants, counter) do
    Enum.reduce(tenants, 0, fn tenant, acc -> acc + counter.(tenant) end)
  end

  defp count_vehicles(tenant) do
    safe_count(Vehicle, tenant)
  end

  defp count_open_issues(tenant) do
    Issue
    |> Ash.Query.filter(status == :open and is_nil(archived_at))
    |> safe_count(tenant)
  end

  defp count_open_work_orders(tenant) do
    WorkOrder
    |> Ash.Query.filter(status in [:open, :in_progress])
    |> safe_count(tenant)
  end

  # A tenant whose schema is missing or mid-migration must not blank the whole
  # dashboard, so a failed per-tenant count contributes zero rather than raising.
  defp safe_count(query_or_resource, tenant) do
    Ash.count!(query_or_resource, tenant: tenant, authorize?: false)
  rescue
    _ -> 0
  end
end
