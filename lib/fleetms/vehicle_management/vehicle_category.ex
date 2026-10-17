defmodule Fleetms.VehicleManagement.VehicleCategory do
  @moduledoc "Broad classification of a vehicle for grouping and reporting."
  use Ash.Type.Enum,
    values: [
      :"Heavy Equipment",
      :"Light Commercial",
      :"Passenger Cars",
      :"Commercial Trucks",
      :"Specialized Vehicles",
      :Motorcycles,
      :"Off Road Vehicles",
      :"Recreational Vehicles"
    ]
end
