defmodule Fleetms.VehicleManagement.VehicleType do
  @moduledoc "Specific kind of vehicle."
  use Ash.Type.Enum,
    values: [
      :Excavator,
      :Bulldozer,
      :Crane,
      :"Dump Truck",
      :Forklift,
      :"Pickup Truck",
      :Van,
      :Sedan,
      :SUV,
      :Hatchback,
      :Coupe,
      :Convertible,
      :Minivan,
      :Wagon,
      :Motorcycle,
      :ATV,
      :"Dirt Bike",
      :Motorhome,
      :Trailer,
      :Truck,
      :"Tractor Trailer",
      :Other
    ]
end
