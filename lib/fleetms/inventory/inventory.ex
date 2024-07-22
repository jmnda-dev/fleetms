defmodule Fleetms.Inventory do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Inventory.Part
    resource Fleetms.Inventory.PartPhoto
    resource Fleetms.Inventory.PartCategory
    resource Fleetms.Inventory.PartUnitMeasurement
    resource Fleetms.Inventory.PartManufacturer
    resource Fleetms.Inventory.InventoryLocation
    resource Fleetms.Inventory.PartInventoryLocation
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
