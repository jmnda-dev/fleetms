defmodule Fleetms.Comments.Commentable do
  @moduledoc """
  Resolves a comment's parent record into the bits the notification producer needs:
  a human `label` ("issue #12"), the `path` the bell should link to, and the
  `participant_ids` — the members connected to that record who should hear about new
  comments (assignee, reporter, and so on).

  Loading uses each resource's primary read with `authorize?: false`, which returns
  the parent's own attributes (including the participant foreign keys) without the
  heavier detail-page loads.
  """

  alias Fleetms.Inspections.Inspection
  alias Fleetms.Maintenance.WorkOrder
  alias Fleetms.VehicleIssues.Issue
  alias Fleetms.VehicleManagement.Vehicle

  @doc "Returns `%{label, path, participant_ids}` for the comment's parent."
  def resolve(%{issue_id: id}, opts) when not is_nil(id) do
    issue = Ash.get!(Issue, id, opts)

    %{
      label: "issue ##{issue.issue_number}",
      path: "/issues/#{id}",
      participant_ids: [issue.assigned_to_id, issue.reported_by_id]
    }
  end

  def resolve(%{work_order_id: id}, opts) when not is_nil(id) do
    work_order = Ash.get!(WorkOrder, id, opts)

    %{
      label: "work order ##{work_order.work_order_number}",
      path: "/work-orders/#{id}",
      participant_ids: [work_order.assigned_to_id, work_order.issued_by_id]
    }
  end

  def resolve(%{vehicle_id: id}, opts) when not is_nil(id) do
    vehicle = Ash.get!(Vehicle, id, opts)

    # A vehicle has no single "owner" to notify, so comments on it only reach mentions.
    %{label: vehicle.name, path: "/vehicles/#{id}", participant_ids: []}
  end

  def resolve(%{inspection_id: id}, opts) when not is_nil(id) do
    inspection = Ash.get!(Inspection, id, opts)

    %{
      label: "an inspection",
      path: "/inspections/#{id}",
      participant_ids: [inspection.submitted_by_id]
    }
  end
end
