defmodule Fleetms.Inspections.InspectionAssignment.Preparations.ListInspectionAssignments do
  @moduledoc """
  Builds the inspection-assignment list: loads the live status plus the vehicle and
  form shown on each row, and applies the requested sort. The open/mine/all facets
  come through the action's own arguments.
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    sort_by = Ash.Query.get_argument(query, :sort_by) || :due_on
    sort_order = Ash.Query.get_argument(query, :sort_order) || :asc

    query
    |> Ash.Query.load([:status, vehicle: [:name], inspection_form: [:title]])
    |> Ash.Query.sort([{sort_by, sort_order}])
  end
end
