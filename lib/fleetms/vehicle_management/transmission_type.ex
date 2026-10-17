defmodule Fleetms.VehicleManagement.TransmissionType do
  @moduledoc "Transmission type."
  use Ash.Type.Enum, values: [:Automatic, :Manual, :CVT, :"Semi-Automatic"]
end
