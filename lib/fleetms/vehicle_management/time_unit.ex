defmodule Fleetms.VehicleManagement.TimeUnit do
  @moduledoc "A unit of time, used for renewal recurrence and reminder lead times."
  use Ash.Type.Enum, values: [:days, :weeks, :months, :years]
end
