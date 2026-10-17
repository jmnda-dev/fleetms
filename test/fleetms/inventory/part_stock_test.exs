defmodule Fleetms.Inventory.PartStockTest do
  use Fleetms.DataCase, async: true

  import Fleetms.InventoryFixtures

  alias Fleetms.Inventory

  setup :shared_org

  describe "inventory locations" do
    test "creates a location and counts its parts", %{scope: scope} do
      location = inventory_location_fixture(scope, %{name: "Main Store"})
      part = part_fixture(scope)
      part_stock_fixture(scope, part, location, Decimal.new("10"))

      loaded = Inventory.get_inventory_location!(location.id, scope: scope)
      assert loaded.name == "Main Store"
      assert loaded.part_count == 1
    end

    test "location names are unique", %{scope: scope} do
      inventory_location_fixture(scope, %{name: "Depot"})

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_inventory_location(%{name: "Depot"}, scope: scope)
    end
  end

  describe "set_part_stock (upsert)" do
    test "setting the same part+location again updates the quantity", %{scope: scope} do
      part = part_fixture(scope)
      location = inventory_location_fixture(scope)

      first = part_stock_fixture(scope, part, location, Decimal.new("5"))
      again = part_stock_fixture(scope, part, location, Decimal.new("9"))

      assert first.id == again.id
      assert Decimal.equal?(again.quantity, Decimal.new("9"))
    end
  end

  describe "adjust" do
    test "receives and consumes at a location", %{scope: scope} do
      part = part_fixture(scope)
      location = inventory_location_fixture(scope)
      stock = part_stock_fixture(scope, part, location, Decimal.new("10"))

      {:ok, received} =
        Inventory.adjust_part_stock(stock, %{delta: Decimal.new("5")}, scope: scope)

      assert Decimal.equal?(received.quantity, Decimal.new("15"))

      {:ok, consumed} =
        Inventory.adjust_part_stock(received, %{delta: Decimal.new("-6")}, scope: scope)

      assert Decimal.equal?(consumed.quantity, Decimal.new("9"))
    end

    test "cannot take a location below zero", %{scope: scope} do
      part = part_fixture(scope)
      location = inventory_location_fixture(scope)
      stock = part_stock_fixture(scope, part, location, Decimal.new("3"))

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.adjust_part_stock(stock, %{delta: Decimal.new("-10")}, scope: scope)
    end
  end

  describe "list_by_part" do
    test "lists a part's stock rows with locations", %{scope: scope} do
      part = part_fixture(scope)
      a = inventory_location_fixture(scope, %{name: "Aisle A"})
      b = inventory_location_fixture(scope, %{name: "Bay B"})
      part_stock_fixture(scope, part, a, Decimal.new("2"))
      part_stock_fixture(scope, part, b, Decimal.new("7"))

      assert {:ok, stocks} = Inventory.list_part_stocks(part.id, scope: scope)
      assert length(stocks) == 2
      assert Enum.map(stocks, & &1.inventory_location.name) == ["Aisle A", "Bay B"]
    end
  end
end
