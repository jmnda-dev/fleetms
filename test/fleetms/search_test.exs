defmodule Fleetms.SearchTest do
  @moduledoc "The ⌘K global search fans a query out across resources, tenant-scoped."
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures

  alias Fleetms.Search

  setup :shared_org

  test "short queries return nothing (no scan on an incidental keystroke)", %{scope: scope} do
    vehicle_fixture(scope, %{name: "Excavator"})
    assert Search.run("E", scope) == []
    assert Search.run("", scope) == []
    assert Search.run(nil, scope) == []
  end

  test "matches a vehicle by name and groups it under :vehicle", %{scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Excavator 900"})

    groups = Search.run("Excavator", scope)
    vehicle_group = Enum.find(groups, &(&1.type == :vehicle))

    assert vehicle_group

    assert Enum.any?(
             vehicle_group.items,
             &(&1.id == vehicle.id and &1.primary == "Excavator 900")
           )
  end

  test "a non-matching query yields no groups", %{scope: scope} do
    vehicle_fixture(scope, %{name: "Excavator 900"})
    assert Search.run("zzzznope", scope) == []
  end
end
