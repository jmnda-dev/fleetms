defmodule Fleetms.Inspections.AssignmentStatus do
  @moduledoc """
  How an inspection assignment stands right now: still to do (`:pending`), past its
  due date and not done (`:overdue`), or completed (`:done`).

  Derived live from `completed_at` and `due_on` (see `InspectionAssignment`), so it
  never goes stale and no job is needed to keep it current.
  """
  use Ash.Type.Enum, values: [:pending, :overdue, :done]
end
