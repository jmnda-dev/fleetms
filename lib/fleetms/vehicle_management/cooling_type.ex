defmodule Fleetms.VehicleManagement.CoolingType do
  @moduledoc "Engine cooling system."
  use Ash.Type.Enum, values: [:Liquid, :Air]
end
