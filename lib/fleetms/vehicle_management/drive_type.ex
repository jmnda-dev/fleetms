defmodule Fleetms.VehicleManagement.DriveType do
  @moduledoc "Which wheels are driven."
  use Ash.Type.Enum,
    values: [
      :"Front Wheel Drive(FWD)",
      :"Rear Wheel Drive(RWD)",
      :"All Wheel Drive(AWD)",
      :"Four Wheel Drive(4WD)"
    ]
end
