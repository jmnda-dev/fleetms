defmodule Fleetms.FuelManagement.FuelEntryTest do
  use Fleetms.DataCase, async: true

  import Fleetms.FuelFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.FuelManagement

  setup :shared_org

  describe "create" do
    test "records a refuel with a money cost and defaults", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:ok, entry} =
               FuelManagement.create_fuel_entry(
                 %{
                   odometer: Decimal.new("12000"),
                   quantity: Decimal.new("45.5"),
                   cost: Money.new(:USD, "72.30"),
                   vehicle_id: vehicle.id
                 },
                 scope: scope
               )

      assert Decimal.equal?(entry.quantity, Decimal.new("45.5"))
      assert entry.fuel_type == :diesel
      assert entry.vehicle_id == vehicle.id
      assert entry.refueled_at
      assert Money.equal?(entry.cost, Money.new(:USD, "72.30"))
    end

    test "preserves each entry's own currency", %{scope: scope} do
      entry = fuel_entry_fixture(scope, %{cost: Money.new(:EUR, "50.00")})

      assert entry.cost.currency == :EUR
      assert Decimal.equal?(entry.cost.amount, Decimal.new("50.00"))
    end

    test "requires a vehicle", %{scope: scope} do
      assert {:error, %Ash.Error.Invalid{}} =
               FuelManagement.create_fuel_entry(
                 %{
                   odometer: Decimal.new("1"),
                   quantity: Decimal.new("1"),
                   cost: Money.new(:USD, "1")
                 },
                 scope: scope
               )
    end

    test "rejects a non-positive quantity", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:error, %Ash.Error.Invalid{}} =
               FuelManagement.create_fuel_entry(
                 %{
                   odometer: Decimal.new("1"),
                   quantity: Decimal.new("0"),
                   cost: Money.new(:USD, "1"),
                   vehicle_id: vehicle.id
                 },
                 scope: scope
               )
    end
  end

  describe "list" do
    test "returns entries newest first", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      older =
        fuel_entry_fixture(scope, %{vehicle_id: vehicle.id, refueled_at: ~U[2026-01-01 08:00:00Z]})

      newer =
        fuel_entry_fixture(scope, %{vehicle_id: vehicle.id, refueled_at: ~U[2026-06-01 08:00:00Z]})

      assert {:ok, page} = FuelManagement.list_fuel_entries(%{}, scope: scope)
      ids = Enum.map(page.results, & &1.id)

      assert Enum.find_index(ids, &(&1 == newer.id)) < Enum.find_index(ids, &(&1 == older.id))
    end

    test "filters by vehicle and fuel type", %{scope: scope} do
      diesel = fuel_entry_fixture(scope, %{fuel_type: :diesel})
      petrol = fuel_entry_fixture(scope, %{fuel_type: :gasoline})

      assert {:ok, page} =
               FuelManagement.list_fuel_entries(
                 %{filters: %{"fuel_types" => [:gasoline]}},
                 scope: scope
               )

      ids = Enum.map(page.results, & &1.id)
      assert petrol.id in ids
      refute diesel.id in ids
    end
  end

  describe "list_by_vehicle" do
    test "returns only the given vehicle's entries", %{scope: scope} do
      v1 = vehicle_fixture(scope)
      v2 = vehicle_fixture(scope)
      mine = fuel_entry_fixture(scope, %{vehicle_id: v1.id})
      _other = fuel_entry_fixture(scope, %{vehicle_id: v2.id})

      assert {:ok, entries} = FuelManagement.list_vehicle_fuel_entries(v1.id, scope: scope)
      ids = Enum.map(entries, & &1.id)

      assert mine.id in ids
      assert Enum.all?(entries, &(&1.vehicle_id == v1.id))
    end
  end

  describe "update / destroy" do
    test "updates an entry", %{scope: scope} do
      entry = fuel_entry_fixture(scope)

      assert {:ok, updated} =
               FuelManagement.update_fuel_entry(entry, %{location: "Shell, Main St"},
                 scope: scope
               )

      assert updated.location == "Shell, Main St"
    end

    test "destroys an entry", %{scope: scope} do
      entry = fuel_entry_fixture(scope)

      assert :ok = FuelManagement.delete_fuel_entry(entry, scope: scope)

      assert {:error, %Ash.Error.Invalid{}} =
               FuelManagement.get_fuel_entry(entry.id, scope: scope)
    end
  end
end
