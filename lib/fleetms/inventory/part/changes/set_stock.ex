defmodule Fleetms.Inventory.Part.Changes.SetStock do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    track_inventory? = Ash.Changeset.get_attribute(changeset, :track_inventory)

    if track_inventory? do
      part_inventory_locations =
        if changeset.action.name == :update_from_part_inventory_location do
            changeset.data
            |> Ash.load!(:part_inventory_locations)
            |> Map.get(:part_inventory_locations)
        else
          case Ash.Changeset.get_argument_or_attribute(changeset, :part_inventory_locations) do
            %Ash.NotLoaded{} ->
              []

            part_inventory_locations when is_list(part_inventory_locations) ->
              part_inventory_locations

            _ ->
              []
          end
        end

      quantity_threshold = Ash.Changeset.get_attribute(changeset, :quantity_threshold) || 0

      stock_quantity =
        Enum.reduce(part_inventory_locations, Decimal.new("0"), fn
          %{"quantity" => quantity}, acc when quantity not in ["", nil] ->
            Decimal.add(acc, Decimal.new(quantity))

          %{quantity: quantity}, acc when not is_nil(quantity) ->
            Decimal.add(acc, quantity)

          _params, acc ->
            acc
        end)

      stock_quantity_status =
        cond do
          stock_quantity == Decimal.new("0") ->
            :"Out of Stock"

          Decimal.compare(stock_quantity, quantity_threshold) == :gt ->
            :"In Stock"

          Decimal.compare(stock_quantity, quantity_threshold) in [:lt, :eq] ->
            :"Stock Low"
        end

      changeset
      |> Ash.Changeset.force_change_attribute(:stock_quantity, stock_quantity)
      |> Ash.Changeset.force_change_attribute(:stock_quantity_status, stock_quantity_status)
    else
      Ash.Changeset.force_change_attribute(changeset, :stock_quantity_status, :"Not tracked")
    end
  end
end
