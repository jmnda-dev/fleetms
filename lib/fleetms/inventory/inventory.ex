defmodule Fleetms.Inventory do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Inventory.Part do
      define :list_parts,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]
    end

    resource Fleetms.Inventory.PartPhoto
    resource Fleetms.Inventory.PartCategory
    resource Fleetms.Inventory.PartUnitMeasurement
    resource Fleetms.Inventory.PartManufacturer

    resource Fleetms.Inventory.InventoryLocation do
      define :list_inventory_locations,
        action: :list,
        args: [:paginate_sort_opts, :search_query]
    end

    resource Fleetms.Inventory.PartInventoryLocation
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
