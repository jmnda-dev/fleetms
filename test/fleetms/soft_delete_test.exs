defmodule Fleetms.SoftDeleteTest do
  @moduledoc """
  Soft delete (AshArchival) behaviour across the resources that opt into it. Deleting
  archives instead of removing; archived rows drop out of the browse/pick lists and a
  partial unique index lets a unique value be reused once the old record is archived.

  Covers the three shapes we use: leaves that hide everywhere (fuel entries, renewals),
  Option B resources that stay resolvable where already referenced (vendors, work orders),
  and storage-owning resources that keep their files on archive but clean them up on a
  separate `purge` (issues, work orders — see the *_media_test files for the file side).
  """
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures
  import Fleetms.FuelFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.IssueFixtures
  import Fleetms.InventoryFixtures

  alias Fleetms.{FuelManagement, Inventory, Maintenance, VehicleIssues, VehicleManagement}
  alias Fleetms.Inventory.InventoryLocation
  alias Fleetms.Maintenance.{Vendor, WorkOrder}

  setup :shared_org

  test "deleting a fuel entry archives it — it's hidden from reads afterwards", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    entry = fuel_entry_fixture(scope, %{vehicle_id: vehicle.id})

    assert :ok = FuelManagement.delete_fuel_entry(entry, scope: scope)
    assert {:error, _} = FuelManagement.get_fuel_entry(entry.id, scope: scope)
  end

  test "an archived fuel entry shows in the archived list and can be restored", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    entry = fuel_entry_fixture(scope, %{vehicle_id: vehicle.id})
    assert :ok = FuelManagement.delete_fuel_entry(entry, scope: scope)

    # hide-everywhere: `get` won't find it, but the archived list does
    archived =
      FuelManagement.list_archived_fuel_entries!(%{}, scope: scope).results
      |> Enum.find(&(&1.id == entry.id))

    assert archived

    assert {:ok, restored} = FuelManagement.restore_fuel_entry(archived, %{}, scope: scope)
    assert is_nil(restored.archived_at)

    assert Enum.any?(
             FuelManagement.list_fuel_entries!(%{}, scope: scope).results,
             &(&1.id == entry.id)
           )
  end

  test "a unique renewal can be recreated after the old one is archived (partial index)", %{
    scope: scope
  } do
    vehicle = vehicle_fixture(scope)
    type = renewal_type_fixture(scope)

    first =
      vehicle_renewal_fixture(scope, %{vehicle_id: vehicle.id, renewal_type_id: type.id})

    assert :ok = VehicleManagement.delete_vehicle_renewal(first, scope: scope)
    # the archived one is hidden
    assert {:error, _} = VehicleManagement.get_vehicle_renewal(first.id, scope: scope)

    # ...and the SAME vehicle + type can be used again — without the partial index
    # this would fail with a "has already been taken" error on the archived row.
    assert {:ok, _second} =
             VehicleManagement.create_vehicle_renewal(
               %{
                 vehicle_id: vehicle.id,
                 renewal_type_id: type.id,
                 due_date: Date.add(Date.utc_today(), 30)
               },
               scope: scope
             )
  end

  test "an archived renewal shows in the archived list and can be restored", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    type = renewal_type_fixture(scope)
    renewal = vehicle_renewal_fixture(scope, %{vehicle_id: vehicle.id, renewal_type_id: type.id})
    assert :ok = VehicleManagement.delete_vehicle_renewal(renewal, scope: scope)

    archived =
      VehicleManagement.list_archived_vehicle_renewals!(%{}, scope: scope).results
      |> Enum.find(&(&1.id == renewal.id))

    assert archived

    assert {:ok, restored} =
             VehicleManagement.restore_vehicle_renewal(archived, %{}, scope: scope)

    assert is_nil(restored.archived_at)

    assert Enum.any?(
             VehicleManagement.list_vehicle_renewals!(%{}, scope: scope).results,
             &(&1.id == renewal.id)
           )
  end

  # Vendor is referenced by completed work orders' outsourced labour, so archiving
  # one must NOT break that history: it's hidden from the browse/pick list, but
  # still resolves via the relationship read (:read) and detail (:get_by_id).
  test "archiving a vendor hides it from the list but keeps it resolvable (Option B)", %{
    scope: scope
  } do
    vendor = vendor_fixture(scope, %{name: "Acme-#{System.unique_integer([:positive])}"})

    assert :ok = Maintenance.delete_vendor(vendor, scope: scope)

    # hidden from the browse/pick list (the :list action filters archived out)
    refute Enum.any?(Maintenance.list_vendors!(%{}, scope: scope), &(&1.id == vendor.id))

    # still resolvable by id (a detail page reached from a historical work order)
    assert {:ok, got} = Maintenance.get_vendor(vendor.id, scope: scope)
    assert got.id == vendor.id

    # still resolvable via the primary :read — the action relationship loads use —
    # so a completed work order's `vendor` keeps resolving.
    ids = Vendor |> Ash.read!(tenant: scope.organization, authorize?: false) |> Enum.map(& &1.id)
    assert vendor.id in ids

    # and the freed-up name can be reused (partial unique index)
    assert {:ok, _} = Maintenance.create_vendor(%{name: vendor.name}, scope: scope)
  end

  test "an archived vendor shows in the archived list and can be restored", %{scope: scope} do
    vendor = vendor_fixture(scope, %{name: "Acme-#{System.unique_integer([:positive])}"})
    assert :ok = Maintenance.delete_vendor(vendor, scope: scope)

    assert vendor.id in (Maintenance.list_archived_vendors!(%{}, scope: scope)
                         |> Enum.map(& &1.id))

    assert {:ok, restored} = Maintenance.restore_vendor(vendor, %{}, scope: scope)
    assert is_nil(restored.archived_at)
    assert Enum.any?(Maintenance.list_vendors!(%{}, scope: scope), &(&1.id == vendor.id))
  end

  test "restoring a vendor is rejected when a live one now holds the same name", %{scope: scope} do
    name = "Acme-#{System.unique_integer([:positive])}"
    vendor = vendor_fixture(scope, %{name: name})
    assert :ok = Maintenance.delete_vendor(vendor, scope: scope)
    assert {:ok, _live} = Maintenance.create_vendor(%{name: name}, scope: scope)

    assert {:error, %Ash.Error.Invalid{}} = Maintenance.restore_vendor(vendor, %{}, scope: scope)
  end

  # Issues clean up their stored photo/document files on a real delete. Archiving
  # must NOT do that — the files (and rows) are kept so the issue can be recovered.
  test "archiving an issue keeps it recoverable and does NOT delete its attachments", %{
    scope: scope
  } do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})

    {:ok, photo} =
      VehicleIssues.create_issue_photo(
        %{issue_id: issue.id, image_key: "k/img", thumbnail_key: "k/thumb"},
        scope: scope
      )

    assert :ok = VehicleIssues.delete_issue(issue, scope: scope)

    # hidden from the browse list
    refute Enum.any?(VehicleIssues.list_issues!(%{}, scope: scope).results, &(&1.id == issue.id))

    # still resolvable by id (an inspection failure can link to it), and its photo
    # row survived — archiving didn't run the file cleanup or the FK cascade
    assert {:ok, got} = VehicleIssues.get_issue(issue.id, scope: scope, load: [:photos])
    assert Enum.map(got.photos, & &1.id) == [photo.id]
  end

  test "purging an issue removes it for good", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})

    assert :ok = VehicleIssues.purge_issue(issue, scope: scope)
    assert {:error, _} = VehicleIssues.get_issue(issue.id, scope: scope)
  end

  test "an archived issue shows in the archived list and can be restored", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})
    assert :ok = VehicleIssues.delete_issue(issue, scope: scope)

    archived_ids =
      VehicleIssues.list_archived_issues!(%{}, scope: scope).results |> Enum.map(& &1.id)

    assert issue.id in archived_ids

    # Restore the record as loaded (what the UI does), not the stale pre-archive struct.
    {:ok, archived} = VehicleIssues.get_issue(issue.id, scope: scope)
    assert {:ok, restored} = VehicleIssues.restore_issue(archived, %{}, scope: scope)
    assert is_nil(restored.archived_at)
    assert Enum.any?(VehicleIssues.list_issues!(%{}, scope: scope).results, &(&1.id == issue.id))
  end

  # Work orders are referenced by the issues they were raised from, so archiving one
  # follows Option B: hidden from the browse lists, but still resolvable by id and via
  # the relationship read. Purging is the real delete (and cleans up storage — see
  # work_order_media_test).
  test "archiving a work order hides it from the lists but keeps it resolvable (Option B)", %{
    scope: scope
  } do
    wo = work_order_fixture(scope)

    assert :ok = Maintenance.delete_work_order(wo, scope: scope)

    # hidden from both browse lists (they filter archived out)
    refute Enum.any?(Maintenance.list_work_orders!(%{}, scope: scope).results, &(&1.id == wo.id))

    refute Enum.any?(
             Maintenance.list_vehicle_work_orders!(wo.vehicle_id, scope: scope),
             &(&1.id == wo.id)
           )

    # still resolvable by id (a detail page reached from a linked issue)
    assert {:ok, got} = Maintenance.get_work_order(wo.id, scope: scope)
    assert got.id == wo.id

    # still resolvable via the primary :read that relationship loads use, so an issue's
    # `work_order` keeps resolving
    ids =
      WorkOrder |> Ash.read!(tenant: scope.organization, authorize?: false) |> Enum.map(& &1.id)

    assert wo.id in ids
  end

  test "purging a work order removes it for good", %{scope: scope} do
    wo = work_order_fixture(scope)

    assert :ok = Maintenance.purge_work_order(wo, scope: scope)
    assert {:error, _} = Maintenance.get_work_order(wo.id, scope: scope)
  end

  test "an archived work order shows in the archived list and can be restored", %{scope: scope} do
    wo = work_order_fixture(scope)
    assert :ok = Maintenance.delete_work_order(wo, scope: scope)

    archived_ids =
      Maintenance.list_archived_work_orders!(%{}, scope: scope).results |> Enum.map(& &1.id)

    assert wo.id in archived_ids

    # Restore the record as loaded (what the UI does), not the stale pre-archive struct.
    {:ok, archived} = Maintenance.get_work_order(wo.id, scope: scope)
    assert {:ok, restored} = Maintenance.restore_work_order(archived, %{}, scope: scope)
    assert is_nil(restored.archived_at)
    assert Enum.any?(Maintenance.list_work_orders!(%{}, scope: scope).results, &(&1.id == wo.id))
  end

  # Inventory locations are referenced by the stock rows held at them, so archiving one
  # follows Option B: hidden from the list/picker, but still resolvable by id and via the
  # relationship a part's stock row uses.
  test "archiving an inventory location hides it from the list but keeps it resolvable (Option B)",
       %{scope: scope} do
    location =
      inventory_location_fixture(scope, %{name: "Depot-#{System.unique_integer([:positive])}"})

    part = part_fixture(scope)
    stock = part_stock_fixture(scope, part, location, Decimal.new("5"))

    assert :ok = Inventory.delete_inventory_location(location, scope: scope)

    # hidden from the browse/pick list (the :list action filters archived out)
    refute Enum.any?(
             Inventory.list_inventory_locations!(%{}, scope: scope),
             &(&1.id == location.id)
           )

    # still resolvable by id (a detail page reached from stock)
    assert {:ok, got} = Inventory.get_inventory_location(location.id, scope: scope)
    assert got.id == location.id

    # still resolvable via the primary :read that relationship loads use, so a part's
    # stock row keeps resolving its location
    ids =
      InventoryLocation
      |> Ash.read!(tenant: scope.organization, authorize?: false)
      |> Enum.map(& &1.id)

    assert location.id in ids

    stock = Ash.load!(stock, :inventory_location, authorize?: false)
    assert stock.inventory_location.id == location.id

    # and the freed-up name can be reused (partial unique index)
    assert {:ok, _} = Inventory.create_inventory_location(%{name: location.name}, scope: scope)
  end

  test "an archived location shows in the archived list and can be restored", %{scope: scope} do
    location =
      inventory_location_fixture(scope, %{name: "Depot-#{System.unique_integer([:positive])}"})

    assert :ok = Inventory.delete_inventory_location(location, scope: scope)

    # in the archived list, not the live one
    archived_ids =
      Inventory.list_archived_inventory_locations!(%{}, scope: scope) |> Enum.map(& &1.id)

    assert location.id in archived_ids

    # restore brings it back to the live list and out of the archived one
    assert {:ok, restored} = Inventory.restore_inventory_location(location, %{}, scope: scope)
    assert is_nil(restored.archived_at)

    assert Enum.any?(
             Inventory.list_inventory_locations!(%{}, scope: scope),
             &(&1.id == location.id)
           )
  end

  test "restoring a location is rejected when a live one now holds the same name", %{scope: scope} do
    name = "Depot-#{System.unique_integer([:positive])}"
    location = inventory_location_fixture(scope, %{name: name})
    assert :ok = Inventory.delete_inventory_location(location, scope: scope)

    # a new live location claims the freed-up name
    assert {:ok, _live} = Inventory.create_inventory_location(%{name: name}, scope: scope)

    # restoring the archived one would collide → rejected
    assert {:error, %Ash.Error.Invalid{}} =
             Inventory.restore_inventory_location(location, %{}, scope: scope)
  end

  # Vehicle groups are current-state config and a vehicle's group is optional, so a group
  # archives hide-everywhere: gone from the group list/picker and its detail, and a vehicle
  # that was in it simply shows no group.
  test "archiving a vehicle group hides it everywhere and frees its name", %{scope: scope} do
    group = vehicle_group_fixture(scope, "Depot-#{System.unique_integer([:positive])}")
    vehicle = vehicle_fixture(scope, %{vehicle_group_id: group.id})

    assert :ok = VehicleManagement.delete_vehicle_group(group, scope: scope)

    # hidden from the group list/picker and from its detail read
    refute Enum.any?(VehicleManagement.list_vehicle_groups!(scope: scope), &(&1.id == group.id))
    assert {:error, _} = VehicleManagement.get_vehicle_group(group.id, scope: scope)

    # a vehicle that was in the archived group now loads no group
    vehicle = Ash.load!(vehicle, :vehicle_group, authorize?: false)
    assert is_nil(vehicle.vehicle_group)

    # the freed-up name can be reused (partial unique index)
    assert {:ok, _} = VehicleManagement.create_vehicle_group(%{name: group.name}, scope: scope)
  end

  # Service reminders are current-state operational data (not historical), so archiving
  # hides them everywhere. The partial index lets a fresh reminder for the same (vehicle,
  # task) be created afterwards — which is exactly what a group re-sync does.
  test "archiving a service reminder hides it everywhere and lets a new one take its place", %{
    scope: scope
  } do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)
    reminder = service_reminder_fixture(scope, vehicle, task)

    assert :ok = Maintenance.delete_service_reminder(reminder, scope: scope)

    # hidden from the list and from its detail read
    refute Enum.any?(
             Maintenance.list_service_reminders!(%{}, scope: scope).results,
             &(&1.id == reminder.id)
           )

    assert {:error, _} = Maintenance.get_service_reminder(reminder.id, scope: scope)

    # a fresh reminder for the same (vehicle, task) can be created past the archived row
    assert {:ok, _} =
             Maintenance.create_service_reminder(
               %{vehicle_id: vehicle.id, service_task_id: task.id, mileage_interval: 5000},
               scope: scope
             )
  end

  test "an archived service reminder shows in the archived list and can be restored", %{
    scope: scope
  } do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)
    reminder = service_reminder_fixture(scope, vehicle, task)

    assert :ok = Maintenance.delete_service_reminder(reminder, scope: scope)

    # Restore the record as loaded from the archived list (that's what the UI does),
    # not the stale pre-archive struct.
    archived =
      Maintenance.list_archived_service_reminders!(%{}, scope: scope).results
      |> Enum.find(&(&1.id == reminder.id))

    assert archived

    assert {:ok, restored} = Maintenance.restore_service_reminder(archived, %{}, scope: scope)
    assert is_nil(restored.archived_at)

    assert Enum.any?(
             Maintenance.list_service_reminders!(%{}, scope: scope).results,
             &(&1.id == reminder.id)
           )
  end
end
