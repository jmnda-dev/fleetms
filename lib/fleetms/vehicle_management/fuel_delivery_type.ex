defmodule Fleetms.VehicleManagement.FuelDeliveryType do
  @moduledoc "How fuel is delivered to the engine."
  use Ash.Type.Enum,
    values: [:"Direct Injection", :"Port Injection", :Carburetor, :"Multi-Point Injection"]
end
