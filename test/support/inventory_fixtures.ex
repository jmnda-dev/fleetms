defmodule Fleetms.InventoryFixtures do
  @moduledoc "Test fixtures for the inventory domain."
  alias Fleetms.Inventory

  def part_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        part_number: "PN-#{System.unique_integer([:positive])}",
        name: "Part #{System.unique_integer([:positive])}"
      })

    Inventory.create_part!(attrs, scope: scope)
  end

  def part_category_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Category #{System.unique_integer([:positive])}"})
    Inventory.upsert_part_category!(attrs, scope: scope)
  end

  def inventory_location_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Location #{System.unique_integer([:positive])}"})
    Inventory.create_inventory_location!(attrs, scope: scope)
  end

  @doc "Sets a part's stock at a location (creates the PartStock row)."
  def part_stock_fixture(scope, part, location, quantity) do
    Inventory.set_part_stock!(
      %{part_id: part.id, inventory_location_id: location.id, quantity: quantity},
      scope: scope
    )
  end
end
