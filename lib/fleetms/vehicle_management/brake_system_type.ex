defmodule Fleetms.VehicleManagement.BrakeSystemType do
  @moduledoc "Braking system type."
  use Ash.Type.Enum, values: [:Hydraulic, :"Hydraulic with ABS", :Neumatic]
end
