defmodule Fleetms.Permissions.SeederTest do
  @moduledoc """
  System-role re-sync: an Administrator must always hold every current permission,
  even in an org created before a feature (and its permissions) existed.
  """
  use Fleetms.DataCase, async: false

  require Ash.Query

  alias Fleetms.Accounts.Role
  alias Fleetms.Permissions.{Cache, Seeder, Sync}

  setup :shared_org

  setup do
    # `Cache.all/0` reads code-declared permissions, but the seeder resolves them
    # to `public.permissions` rows — populate that table (Sync is off in test).
    Sync.sync!()
    :ok
  end

  test "sync_for_org! grants every current permission to Administrator", %{org: org} do
    # Simulate an Administrator seeded before newer modules shipped.
    admin = system_role("Administrator", org)
    strip_permissions!(admin, org)
    assert permission_names(admin, org) == []

    Seeder.sync_for_org!(org)

    granted = permission_names(system_role("Administrator", org), org)
    all_names = Enum.map(Cache.all(), & &1.name)

    assert Enum.sort(granted) == Enum.sort(all_names)
    # The modules that regressed for pre-existing orgs.
    assert "view_issues" in granted
    assert "view_vehicles" in granted
  end

  test "sync_for_org! grants Read Only only view_ permissions", %{org: org} do
    Seeder.sync_for_org!(org)

    granted = permission_names(system_role("Read Only", org), org)

    assert granted != []
    assert Enum.all?(granted, &String.starts_with?(&1, "view_"))
  end

  test "sync_for_org! grants Client only its operational views plus reporting issues",
       %{org: org} do
    Seeder.sync_for_org!(org)

    granted = permission_names(system_role("Client", org), org)

    # Sees their own fleet's operational modules...
    assert "view_vehicles" in granted
    assert "view_issues" in granted
    assert "view_work_orders" in granted
    assert "view_fuel_entries" in granted
    # ...and can raise an issue...
    assert "create_issue" in granted
    # ...but not org administration, inventory, vendors or the shared catalog...
    refute "view_users" in granted
    refute "view_parts" in granted
    refute "view_vendors" in granted
    refute "view_service_tasks" in granted
    refute "view_roles" in granted
    # ...and no management (create/update/delete) beyond raising issues.
    refute "create_vehicle" in granted
    refute "delete_issue" in granted
    assert Enum.all?(granted, &(String.starts_with?(&1, "view_") or &1 == "create_issue"))
  end

  test "sync_for_org! is idempotent", %{org: org} do
    Seeder.sync_for_org!(org)
    first = permission_names(system_role("Administrator", org), org)

    Seeder.sync_for_org!(org)
    second = permission_names(system_role("Administrator", org), org)

    assert Enum.sort(first) == Enum.sort(second)
  end

  defp system_role(name, org) do
    Role
    |> Ash.Query.filter(name == ^name and is_system == true)
    |> Ash.read_one!(authorize?: false, tenant: org)
  end

  defp strip_permissions!(role, org) do
    role
    |> Ash.Changeset.for_update(:set_permissions, %{permission_ids: []})
    |> Ash.update!(authorize?: false, tenant: org)
  end

  defp permission_names(role, org) do
    role
    |> Ash.load!([:permissions], authorize?: false, tenant: org)
    |> Map.fetch!(:permissions)
    |> Enum.map(& &1.name)
  end
end
