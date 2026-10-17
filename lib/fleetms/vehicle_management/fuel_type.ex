defmodule Fleetms.VehicleManagement.FuelType do
  @moduledoc "Fuel an engine runs on."
  use Ash.Type.Enum, values: [:Gasoline, :Diesel, :Electric, :Hybrid, :Hydrogen]
end
