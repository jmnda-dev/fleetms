defmodule Fleetms.VehicleManagement.EngineConfiguration do
  @moduledoc "Cylinder layout of the engine."
  use Ash.Type.Enum, values: [:Inline, :V, :W, :Boxer, :Flat, :Rotary]
end
