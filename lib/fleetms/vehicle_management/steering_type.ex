defmodule Fleetms.VehicleManagement.SteeringType do
  @moduledoc "Steering mechanism."
  use Ash.Type.Enum,
    values: [
      :"Steering rack and pinion",
      :"Recirculating Ball Steering",
      :"Electric Power Steering",
      :"Hydraulic Power Steering",
      :"Variable Assist Power Steering",
      :"Four-Wheel Steering"
    ]
end
