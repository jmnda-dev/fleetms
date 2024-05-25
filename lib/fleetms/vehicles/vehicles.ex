defmodule Fleetms.Vehicles do
  @moduledoc """
  A Ash domain module for interacting with resources in the Vehicles context.
  """

  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Vehicles.VehicleMake
    resource Fleetms.Vehicles.VehicleModel

    resource Fleetms.Vehicles.Vehicle do
      define :add_vehicle, action: :create, args: [:vehicle_model]
      define :update_vehicle, action: :create, args: [:vehicle_model]
    end
  end

  admin do
    show? true
  end
end
