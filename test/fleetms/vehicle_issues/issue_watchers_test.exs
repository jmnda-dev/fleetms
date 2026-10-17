defmodule Fleetms.VehicleIssues.IssueWatchersTest do
  @moduledoc "Watching an issue and being notified when it's resolved or closed."
  use Fleetms.DataCase, async: false

  import Fleetms.AccountsFixtures
  import Fleetms.IssueFixtures

  alias Fleetms.Notifications
  alias Fleetms.Scope
  alias Fleetms.VehicleIssues

  setup :shared_org

  test "watching is idempotent", %{scope: scope} do
    issue = issue_fixture(scope)

    VehicleIssues.watch_issue!(%{issue_id: issue.id, user_id: scope.user.id}, scope: scope)
    VehicleIssues.watch_issue!(%{issue_id: issue.id, user_id: scope.user.id}, scope: scope)

    watchers =
      VehicleIssues.list_issue_watchers!(scope: scope)
      |> Enum.filter(&(&1.issue_id == issue.id))

    assert length(watchers) == 1
  end

  test "unwatching removes the watcher", %{scope: scope} do
    issue = issue_fixture(scope)
    w = VehicleIssues.watch_issue!(%{issue_id: issue.id, user_id: scope.user.id}, scope: scope)

    :ok = VehicleIssues.unwatch_issue(w, scope: scope)

    assert VehicleIssues.list_issue_watchers!(scope: scope)
           |> Enum.filter(&(&1.issue_id == issue.id)) == []
  end

  test "resolving an issue notifies a watcher who isn't the actor", %{scope: scope, org: org} do
    watcher = user_fixture()
    issue = issue_fixture(scope)

    # Add the watcher row directly (watch authorization is covered above); the
    # subject here is the lifecycle notification fan-out.
    VehicleIssues.watch_issue!(%{issue_id: issue.id, user_id: watcher.id},
      tenant: org,
      authorize?: false
    )

    {:ok, _} = VehicleIssues.resolve_issue(issue, scope: scope)

    titles =
      Notifications.list_notifications!(scope: Scope.new(watcher, org, false))
      |> Enum.map(& &1.title)

    assert Enum.any?(titles, &(&1 =~ "was resolved"))
  end

  test "the actor who resolves is not notified even if watching", %{scope: scope} do
    issue = issue_fixture(scope)
    VehicleIssues.watch_issue!(%{issue_id: issue.id, user_id: scope.user.id}, scope: scope)

    {:ok, _} = VehicleIssues.resolve_issue(issue, scope: scope)

    titles = Notifications.list_notifications!(scope: scope) |> Enum.map(& &1.title)
    refute Enum.any?(titles, &(&1 =~ "was resolved"))
  end
end
