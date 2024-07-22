defmodule Fleetms.Inventory.Resources.Part.Validations.ValidateInventoryTracking do
  use Ash.Resource.Validation

  def validate(changeset, _opts, _context) do
    track_inventory = Ash.Changeset.get_attribute(changeset, :track_inventory)

    part_inventory_locations =
      Ash.Changeset.get_argument_or_attribute(changeset, :part_inventory_locations)

    # I write `track_inventory == true` because sometimes `track_inventory` might be `nil`, and if it is `nil`, `:ok` should be returned(it is considerd valid)
    if track_inventory == true and part_inventory_locations == [] do
      {:error,
       field: :track_inventory,
       message: "An Inventory Location must be added if Track Inventory is enabled"}
    else
      :ok
    end
  end
end
