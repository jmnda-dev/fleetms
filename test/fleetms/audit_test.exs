defmodule Fleetms.AuditTest do
  @moduledoc """
  AshPaperTrail audit versions on the tracked resources: each action writes a version
  row with the acting user and the action name, and versions outlive a hard purge.
  """
  use Fleetms.DataCase, async: true

  import Fleetms.IssueFixtures

  alias Fleetms.VehicleIssues
  alias Fleetms.VehicleIssues.Issue

  require Ash.Query

  setup :shared_org

  defp versions(source_id, scope) do
    Issue.Version
    |> Ash.Query.filter(version_source_id == ^source_id)
    |> Ash.Query.sort(version_inserted_at: :asc)
    |> Ash.read!(tenant: scope.organization, authorize?: false)
  end

  test "creating and changing an issue records versions with the actor and action", %{
    scope: scope
  } do
    issue = issue_fixture(scope)

    assert [create_v] = versions(issue.id, scope)
    assert create_v.version_action_type == :create
    assert create_v.version_action_name == :create
    assert create_v.user_id == scope.user.id

    {:ok, _} = VehicleIssues.resolve_issue(issue, %{resolve_comments: "done"}, scope: scope)

    names = versions(issue.id, scope) |> Enum.map(& &1.version_action_name)
    assert :resolve in names
  end

  test "an edit records what changed", %{scope: scope} do
    issue = issue_fixture(scope, %{priority: :Low})
    {:ok, _} = VehicleIssues.update_issue(issue, %{priority: :High}, scope: scope)

    update = versions(issue.id, scope) |> Enum.find(&(&1.version_action_name == :update))
    assert update
    assert Map.has_key?(update.changes, "priority")
  end

  test "versions survive a purge", %{scope: scope} do
    issue = issue_fixture(scope)
    assert versions(issue.id, scope) != []

    assert :ok = VehicleIssues.purge_issue(issue, scope: scope)

    # the audit trail is kept even though the record is gone
    assert versions(issue.id, scope) != []
    assert {:error, _} = VehicleIssues.get_issue(issue.id, scope: scope)
  end
end
