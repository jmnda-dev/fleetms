defmodule Fleetms.VehicleManagement.VehicleStatus do
  @moduledoc "Operational status of a vehicle."
  use Ash.Type.Enum, values: [:Active, :Maintenance, :"Out-of-Service", :Inactive, :Sold]
end
