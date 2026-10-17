defmodule Fleetms.FuelManagement do
  @moduledoc """
  The fuel domain: per-vehicle refuel/recharge entries and their costs. Fuel
  economy and reporting are derived from these entries in a later workstream.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/fuel-entries", Fleetms.FuelManagement.FuelEntry do
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
    resource Fleetms.FuelManagement.FuelEntry do
      define :list_fuel_entries, action: :list
      define :list_archived_fuel_entries, action: :list_archived
      define :get_fuel_entry, action: :get_by_id, args: [:id]
      define :list_vehicle_fuel_entries, action: :list_by_vehicle, args: [:vehicle_id]
      define :create_fuel_entry, action: :create
      define :update_fuel_entry, action: :update
      define :delete_fuel_entry, action: :destroy
      define :restore_fuel_entry, action: :restore
    end
  end
end
