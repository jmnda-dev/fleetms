defmodule Fleetms.VehicleManagement.Aspiration do
  @moduledoc "Engine aspiration / forced-induction type."
  use Ash.Type.Enum,
    values: [
      :"Naturally Aspirated",
      :Turbocharged,
      :Supercharged,
      :"Twin Turbocharged",
      :"Twin Supercharged",
      :"Twin Turbocharged and Supercharged"
    ]
end
