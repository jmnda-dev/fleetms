defmodule Fleetms.VehicleManagement.BrakeType do
  @moduledoc "Brake hardware type (front or rear)."
  use Ash.Type.Enum,
    values: [
      :"Ventilated Disc",
      :"Solid Disc",
      :"Composite Rotors",
      :"Carbon Ceramic Brakes",
      :"Drum Brakes",
      :"Electromagnetic Brakes",
      :"Integrated Brake System"
    ]
end
