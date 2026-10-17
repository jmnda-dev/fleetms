defmodule Fleetms.Inventory.PartTest do
  use Fleetms.DataCase, async: true

  import Fleetms.InventoryFixtures

  alias Fleetms.Inventory

  setup :shared_org

  describe "soft delete (Option B)" do
    test "archiving a part hides it from the list but keeps it resolvable, and frees its number",
         %{scope: scope} do
      part = part_fixture(scope, %{part_number: "PN-ARCH-#{System.unique_integer([:positive])}"})

      assert :ok = Inventory.delete_part(part, scope: scope)

      # hidden from the browse/pick list
      refute Enum.any?(Inventory.list_parts!(%{}, scope: scope).results, &(&1.id == part.id))

      # still resolvable by id and via the primary :read (what a completed work
      # order's line item uses to load its part), so cost history keeps its part
      assert {:ok, got} = Inventory.get_part(part.id, scope: scope)
      assert got.id == part.id

      ids =
        Inventory.Part
        |> Ash.read!(tenant: scope.organization, authorize?: false)
        |> Enum.map(& &1.id)

      assert part.id in ids

      # the freed-up part number can be reused (partial unique index)
      assert {:ok, _} =
               Inventory.create_part(%{part_number: part.part_number, name: "Reused"},
                 scope: scope
               )
    end

    test "archived parts show in the archived list and can be restored", %{scope: scope} do
      part = part_fixture(scope, %{part_number: "PN-RES-#{System.unique_integer([:positive])}"})
      assert :ok = Inventory.delete_part(part, scope: scope)

      # appears in the archived list, not the live one
      archived_ids =
        Inventory.list_archived_parts!(%{}, scope: scope).results |> Enum.map(& &1.id)

      assert part.id in archived_ids
      refute Enum.any?(Inventory.list_parts!(%{}, scope: scope).results, &(&1.id == part.id))

      # restore brings it back into the live catalogue and out of the archived list
      assert {:ok, restored} = Inventory.restore_part(part, %{}, scope: scope)
      assert is_nil(restored.archived_at)
      assert Enum.any?(Inventory.list_parts!(%{}, scope: scope).results, &(&1.id == part.id))

      refute Enum.any?(
               Inventory.list_archived_parts!(%{}, scope: scope).results,
               &(&1.id == part.id)
             )
    end

    test "restoring is rejected when a live part now holds the same number", %{scope: scope} do
      number = "PN-DUP-#{System.unique_integer([:positive])}"
      part = part_fixture(scope, %{part_number: number})
      assert :ok = Inventory.delete_part(part, scope: scope)

      # a new live part claims the freed-up number
      assert {:ok, _live} = Inventory.create_part(%{part_number: number}, scope: scope)

      # restoring the archived one would collide with the live one → rejected
      assert {:error, %Ash.Error.Invalid{}} = Inventory.restore_part(part, %{}, scope: scope)
    end
  end

  describe "create" do
    test "creates a part with a money unit cost", %{scope: scope} do
      assert {:ok, part} =
               Inventory.create_part(
                 %{
                   part_number: "OIL-5W30",
                   name: "Engine oil",
                   unit_cost: Money.new(:USD, "12.50")
                 },
                 scope: scope
               )

      assert part.part_number == "OIL-5W30"
      assert Money.equal?(part.unit_cost, Money.new(:USD, "12.50"))
      # Untracked by default, stocked nowhere → "Not tracked", total 0.
      assert {:ok, loaded} = Inventory.get_part(part.id, scope: scope)
      assert loaded.stock_status == "Not tracked"
      assert Decimal.equal?(loaded.total_stock, Decimal.new(0))
    end

    test "requires a part number", %{scope: scope} do
      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_part(%{name: "No number"}, scope: scope)
    end

    test "rejects a duplicate part number", %{scope: scope} do
      part_fixture(scope, %{part_number: "DUP-1"})

      assert {:error, %Ash.Error.Invalid{}} =
               Inventory.create_part(%{part_number: "DUP-1"}, scope: scope)
    end

    test "assigns a category", %{scope: scope} do
      category = part_category_fixture(scope, %{name: "Filters"})

      assert {:ok, part} =
               Inventory.create_part(%{part_number: "FIL-1", category_id: category.id},
                 scope: scope
               )

      assert part.category_id == category.id
    end
  end

  describe "total_stock / stock_status" do
    test "total_stock sums across locations", %{scope: scope} do
      part = part_fixture(scope, %{track_inventory: true, quantity_threshold: 5})
      warehouse = inventory_location_fixture(scope, %{name: "Warehouse"})
      van = inventory_location_fixture(scope, %{name: "Van 3"})

      part_stock_fixture(scope, part, warehouse, Decimal.new("8"))
      part_stock_fixture(scope, part, van, Decimal.new("4"))

      loaded = Inventory.get_part!(part.id, scope: scope)
      assert Decimal.equal?(loaded.total_stock, Decimal.new("12"))
      assert loaded.stock_status == "In stock"
    end

    test "reflects the threshold across locations", %{scope: scope} do
      part = part_fixture(scope, %{track_inventory: true, quantity_threshold: 5})
      location = inventory_location_fixture(scope)

      part_stock_fixture(scope, part, location, Decimal.new("3"))
      assert Inventory.get_part!(part.id, scope: scope).stock_status == "Low"

      assert Inventory.get_part!(part.id, scope: scope) |> Map.fetch!(:total_stock)
    end

    test "no stock anywhere reads Out of stock when tracked", %{scope: scope} do
      part = part_fixture(scope, %{track_inventory: true, quantity_threshold: 5})
      assert Inventory.get_part!(part.id, scope: scope).stock_status == "Out of stock"
    end
  end

  describe "list" do
    test "searches by part number and filters by category", %{scope: scope} do
      category = part_category_fixture(scope, %{name: "Brakes"})

      match =
        part_fixture(scope, %{
          part_number: "Brakepad",
          name: "Brakepad",
          category_id: category.id
        })

      _other = part_fixture(scope, %{part_number: "Sparkplug", name: "Sparkplug"})

      assert {:ok, page} = Inventory.list_parts(%{search_query: "Brakepad"}, scope: scope)
      assert Enum.map(page.results, & &1.id) == [match.id]

      assert {:ok, filtered} =
               Inventory.list_parts(%{filters: %{"category_id" => category.id}}, scope: scope)

      assert Enum.map(filtered.results, & &1.id) == [match.id]
    end

    test "filters by stock status", %{scope: scope} do
      low = part_fixture(scope, %{track_inventory: true, quantity_threshold: 5})
      location = inventory_location_fixture(scope)
      part_stock_fixture(scope, low, location, Decimal.new("2"))

      _ok = part_fixture(scope, %{track_inventory: true, quantity_threshold: 1})

      assert {:ok, page} =
               Inventory.list_parts(%{filters: %{"statuses" => ["Low"]}}, scope: scope)

      assert low.id in Enum.map(page.results, & &1.id)
      assert Enum.all?(page.results, &(&1.stock_status == "Low"))
    end
  end
end
