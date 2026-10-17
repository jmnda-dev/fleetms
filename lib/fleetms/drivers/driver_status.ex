defmodule Fleetms.Drivers.DriverStatus do
  @moduledoc "Whether a driver is currently available to be assigned a vehicle."
  use Ash.Type.Enum, values: [:active, :inactive]
end
