defmodule Fleetms.VehicleManagement.ValveTrainDesign do
  @moduledoc "Valve-train / camshaft layout."
  use Ash.Type.Enum,
    values: [
      :"Overhead Valve(OHV)",
      :"Overhead Camshaft(OHC)",
      :"Single Overhead Camshaft(SOHC)",
      :"Dual Overhead Camshaft(DOHC)"
    ]
end
