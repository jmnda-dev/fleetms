defmodule Fleetms.Inventory do
  @moduledoc """
  The inventory domain: the parts catalogue a fleet keeps to service its vehicles,
  their stock levels, and the categories that organize them. Later consumed by
  work orders.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/parts", Fleetms.Inventory.Part do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end

      base_route "/part-stocks", Fleetms.Inventory.PartStock do
        index :read
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:adjust, route: "/:id/adjust")
        delete(:destroy)
      end

      base_route "/inventory-locations", Fleetms.Inventory.InventoryLocation do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.Inventory.Part do
      define :list_parts, action: :list
      define :list_archived_parts, action: :list_archived
      define :get_part, action: :get_by_id, args: [:id]
      define :create_part, action: :create
      define :update_part, action: :update
      define :delete_part, action: :destroy
      define :restore_part, action: :restore
    end

    resource Fleetms.Inventory.PartCategory do
      define :list_part_categories, action: :read
      define :get_part_category, action: :get_by_id, args: [:id]
      define :upsert_part_category, action: :create
      define :delete_part_category, action: :destroy
    end

    resource Fleetms.Inventory.InventoryLocation do
      define :list_inventory_locations, action: :list
      define :list_archived_inventory_locations, action: :list_archived
      define :get_inventory_location, action: :get_by_id, args: [:id]
      define :create_inventory_location, action: :create
      define :update_inventory_location, action: :update
      define :delete_inventory_location, action: :destroy
      define :restore_inventory_location, action: :restore
    end

    resource Fleetms.Inventory.PartStock do
      define :list_part_stocks, action: :list_by_part, args: [:part_id]
      define :get_part_stock, action: :get_by_id, args: [:id]
      define :set_part_stock, action: :create
      define :update_part_stock, action: :update
      define :adjust_part_stock, action: :adjust
      define :delete_part_stock, action: :destroy
    end
  end
end
