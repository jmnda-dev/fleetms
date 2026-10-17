defmodule Fleetms.VehicleManagement.BrakeAssist do
  @moduledoc "Braking assistance system."
  use Ash.Type.Enum, values: [:"ABS(Anti-lock braking system)", :Other]
end
