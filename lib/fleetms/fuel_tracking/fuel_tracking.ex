defmodule Fleetms.FuelTracking do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.FuelTracking.FuelHistory
    resource Fleetms.FuelTracking.FuelHistoryPhoto
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
