defmodule Fleetms.Maintenance.WorkOrderIssuesTest do
  use Fleetms.DataCase

  import Fleetms.IssueFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.VehicleIssues

  setup :shared_org

  test "linking an issue to a work order sets its work_order_id", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})

    wo =
      Maintenance.create_work_order!(
        %{vehicle_id: vehicle.id, issue_ids: [issue.id]},
        scope: scope
      )

    assert VehicleIssues.get_issue!(issue.id, scope: scope).work_order_id == wo.id
  end

  test "unlinking an issue on update clears its work_order_id", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})

    wo =
      Maintenance.create_work_order!(
        %{vehicle_id: vehicle.id, issue_ids: [issue.id]},
        scope: scope
      )

    Maintenance.update_work_order!(wo, %{vehicle_id: vehicle.id, issue_ids: []}, scope: scope)

    assert VehicleIssues.get_issue!(issue.id, scope: scope).work_order_id == nil
  end

  test "completing the work order resolves its still-open linked issues", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})
    assert issue.status == :open

    wo =
      Maintenance.create_work_order!(
        %{vehicle_id: vehicle.id, issue_ids: [issue.id]},
        scope: scope
      )

    Maintenance.complete_work_order!(wo, scope: scope)

    assert VehicleIssues.get_issue!(issue.id, scope: scope).status == :resolved
  end

  test "completing does not disturb an already-resolved linked issue", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})
    issue = VehicleIssues.resolve_issue!(issue, scope: scope)
    assert issue.status == :resolved

    wo =
      Maintenance.create_work_order!(
        %{vehicle_id: vehicle.id, issue_ids: [issue.id]},
        scope: scope
      )

    # completes without error (no illegal re-resolve of the closed/resolved issue)
    Maintenance.complete_work_order!(wo, scope: scope)

    assert VehicleIssues.get_issue!(issue.id, scope: scope).status == :resolved
  end
end
