defmodule Fleetms.VehicleManagement.SteeringSide do
  @moduledoc "Side of the vehicle the steering wheel is on."
  use Ash.Type.Enum, values: [:"Right Hand Drive", :"Left Hand Drive"]
end
