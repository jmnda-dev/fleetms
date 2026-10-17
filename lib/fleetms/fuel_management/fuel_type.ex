defmodule Fleetms.FuelManagement.FuelType do
  @moduledoc "The kind of fuel (or energy) a refuel entry records."
  use Ash.Type.Enum, values: [:gasoline, :diesel, :electric, :hydrogen, :lpg, :other]
end
