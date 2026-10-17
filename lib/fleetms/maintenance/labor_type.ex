defmodule Fleetms.Maintenance.LaborType do
  @moduledoc """
  Who performed labour on a work-order line: an internal `:technician` (a member,
  billed as hours × rate) or an outsourced `:vendor` (billed as a flat charge).
  """
  use Ash.Type.Enum, values: [:technician, :vendor]
end
