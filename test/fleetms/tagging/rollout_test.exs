defmodule Fleetms.Tagging.RolloutTest do
  @moduledoc """
  Tags work the same way across every taggable resource — work orders, vehicles and
  parts — and one tag in the org's vocabulary can be attached to records of different
  kinds.
  """
  use Fleetms.DataCase, async: true

  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures
  import Fleetms.InventoryFixtures

  alias Fleetms.Inventory
  alias Fleetms.Maintenance
  alias Fleetms.Tagging
  alias Fleetms.VehicleManagement

  setup :shared_org

  defp names(record), do: record.tags |> Enum.map(&to_string(&1.name)) |> Enum.sort()

  test "a work order can be tagged and re-synced", %{scope: scope} do
    wo = work_order_fixture(scope, %{tags: ["recall", "warranty"]})
    wo = Maintenance.get_work_order!(wo.id, scope: scope, load: [:tags])
    assert names(wo) == ["recall", "warranty"]

    # The work order's update action always needs its vehicle_id.
    {:ok, _} =
      Maintenance.update_work_order(wo, %{tags: ["warranty"], vehicle_id: wo.vehicle_id},
        scope: scope
      )

    wo = Maintenance.get_work_order!(wo.id, scope: scope, load: [:tags])
    assert names(wo) == ["warranty"]
  end

  test "a vehicle can be tagged", %{scope: scope} do
    vehicle = vehicle_fixture(scope, %{tags: ["leased"]})
    vehicle = VehicleManagement.get_vehicle!(vehicle.id, scope: scope, load: [:tags])
    assert names(vehicle) == ["leased"]
  end

  test "a part can be tagged", %{scope: scope} do
    part = part_fixture(scope, %{tags: ["consumable", "oem"]})
    part = Inventory.get_part!(part.id, scope: scope, load: [:tags])
    assert names(part) == ["consumable", "oem"]
  end

  test "one tag is shared across different record types", %{scope: scope} do
    vehicle = vehicle_fixture(scope, %{tags: ["priority"]})
    wo = work_order_fixture(scope, %{tags: ["priority"]})
    part = part_fixture(scope, %{tags: ["priority"]})

    # All three point at the same single tag in the vocabulary.
    assert [tag] = Tagging.list_tags!(scope: scope)
    assert to_string(tag.name) == "priority"

    for record <- [
          VehicleManagement.get_vehicle!(vehicle.id, scope: scope, load: [:tags]),
          Maintenance.get_work_order!(wo.id, scope: scope, load: [:tags]),
          Inventory.get_part!(part.id, scope: scope, load: [:tags])
        ] do
      assert [attached] = record.tags
      assert attached.id == tag.id
    end
  end
end
