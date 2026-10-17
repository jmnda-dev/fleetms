defmodule Fleetms.Permissions.Dsl.PermissionEntity do
  @moduledoc """
  Represents a single declared permission on an Ash Resource.
  """
  defstruct [
    # atom — e.g. :create_vehicle (internal key, used in policy checks)
    :name,
    # atom or list of atoms — the Ash action(s) this guards
    :action,
    # string — human-readable, shown in UI ("Create Vehicle")
    :label,
    # string | nil — longer description for UI tooltips
    :description,
    # string | nil — UI grouping ("Fleet Management"). Auto-derived if nil.
    :group,
    # boolean — defaults true; kept for future soft-deprecation support
    active: true,
    # required by Spark to carry source annotations
    __spark_metadata__: nil
  ]
end
