defmodule Fleetms.Maintenance.RepairCategory do
  @moduledoc "Why a work order exists — the nature of the repair."
  use Ash.Type.Enum, values: [:preventive, :corrective, :emergency, :scheduled]
end
