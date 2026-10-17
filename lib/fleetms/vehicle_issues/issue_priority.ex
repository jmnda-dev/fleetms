defmodule Fleetms.VehicleIssues.IssuePriority do
  @moduledoc "How urgently an issue needs attention."
  use Ash.Type.Enum, values: [:None, :Low, :Medium, :High]
end
