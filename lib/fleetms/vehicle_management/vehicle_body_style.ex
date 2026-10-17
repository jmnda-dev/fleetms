defmodule Fleetms.VehicleManagement.VehicleBodyStyle do
  @moduledoc "Body style / silhouette of a vehicle."
  use Ash.Type.Enum,
    values: [
      :Sedan,
      :Coupe,
      :Convertible,
      :Hatchback,
      :Wagon,
      :SUV,
      :Van,
      :Truck,
      :Minivan,
      :Crossover,
      :"Pickup Truck",
      :Trailer,
      :Motorcycle,
      :Other
    ]
end
