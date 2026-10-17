defmodule Fleetms.Maintenance.TimeUnit do
  @moduledoc "The unit a service reminder's time interval is measured in."
  use Ash.Type.Enum, values: [:day, :week, :month, :year]
end
