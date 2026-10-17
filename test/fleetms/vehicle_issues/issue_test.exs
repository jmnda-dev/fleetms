defmodule Fleetms.VehicleIssues.IssueTest do
  use Fleetms.DataCase, async: true

  import Fleetms.AccountsFixtures
  import Fleetms.IssueFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Notifications
  alias Fleetms.Scope
  alias Fleetms.VehicleIssues

  setup :shared_org

  describe "create" do
    test "opens an issue: status :open, reporter is the actor, number assigned",
         %{scope: scope, owner: owner} do
      vehicle = vehicle_fixture(scope)

      assert {:ok, issue} =
               VehicleIssues.create_issue(%{title: "Brake noise", vehicle_id: vehicle.id},
                 scope: scope
               )

      assert issue.status == :open
      assert issue.priority == :Low
      assert issue.reported_by_id == owner.id
      assert is_integer(issue.issue_number)
      assert issue.reported_at
    end

    test "issue_number increments per organization", %{scope: scope} do
      a = issue_fixture(scope)
      b = issue_fixture(scope)

      assert b.issue_number == a.issue_number + 1
    end

    test "requires a title", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleIssues.create_issue(%{vehicle_id: vehicle.id}, scope: scope)
    end

    test "requires a vehicle", %{scope: scope} do
      assert {:error, %Ash.Error.Invalid{}} =
               VehicleIssues.create_issue(%{title: "Orphan"}, scope: scope)
    end

    test "sanitizes the rich-text description", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:ok, issue} =
               VehicleIssues.create_issue(
                 %{
                   title: "XSS",
                   vehicle_id: vehicle.id,
                   description: "<p>ok</p><script>alert(1)</script>"
                 },
                 scope: scope
               )

      refute issue.description =~ "<script>"
      assert issue.description =~ "ok"
    end
  end

  describe "lifecycle (state machine)" do
    test "resolve moves open -> resolved and stamps resolved_at", %{scope: scope} do
      issue = issue_fixture(scope)

      assert {:ok, resolved} =
               VehicleIssues.resolve_issue(issue, %{resolve_comments: "Replaced pads"},
                 scope: scope
               )

      assert resolved.status == :resolved
      assert resolved.resolved_at
    end

    test "close moves open -> closed and stamps closed_at", %{scope: scope} do
      issue = issue_fixture(scope)

      assert {:ok, closed} = VehicleIssues.close_issue(issue, %{}, scope: scope)
      assert closed.status == :closed
      assert closed.closed_at
    end

    test "reopen moves closed -> open and clears resolution", %{scope: scope} do
      issue = issue_fixture(scope)
      {:ok, closed} = VehicleIssues.close_issue(issue, %{close_comments: "Dup"}, scope: scope)

      assert {:ok, reopened} = VehicleIssues.reopen_issue(closed, %{}, scope: scope)
      assert reopened.status == :open
      assert is_nil(reopened.closed_at)
      assert is_nil(reopened.close_comments)
    end

    test "rejects an illegal transition (resolve on a closed issue)", %{scope: scope} do
      issue = issue_fixture(scope)
      {:ok, closed} = VehicleIssues.close_issue(issue, %{}, scope: scope)

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleIssues.resolve_issue(closed, %{}, scope: scope)
    end
  end

  describe "list" do
    test "filters by status", %{scope: scope} do
      open = issue_fixture(scope)
      to_close = issue_fixture(scope)
      {:ok, _} = VehicleIssues.close_issue(to_close, %{}, scope: scope)

      assert {:ok, page} =
               VehicleIssues.list_issues(%{filters: %{"statuses" => [:open]}}, scope: scope)

      ids = Enum.map(page.results, & &1.id)
      assert open.id in ids
      refute to_close.id in ids
    end
  end

  describe "notification producers" do
    test "assigning an issue notifies the assignee", %{scope: scope, org: org} do
      assignee = user_fixture()
      vehicle = vehicle_fixture(scope)

      {:ok, issue} =
        VehicleIssues.create_issue(
          %{title: "Flat tyre", vehicle_id: vehicle.id, assigned_to_id: assignee.id},
          scope: scope
        )

      assert [notification] = notifications_for(assignee, org)
      assert notification.type == "issue_assigned"
      assert notification.title == "You were assigned issue ##{issue.issue_number}"
      assert notification.path == "/issues/#{issue.id}"
      assert is_nil(notification.read_at)
    end

    test "assigning to yourself does not notify", %{scope: scope, org: org, owner: owner} do
      vehicle = vehicle_fixture(scope)

      {:ok, _issue} =
        VehicleIssues.create_issue(
          %{title: "Mine", vehicle_id: vehicle.id, assigned_to_id: owner.id},
          scope: scope
        )

      assert notifications_for(owner, org) == []
    end

    test "reassigning on update notifies the new assignee", %{scope: scope, org: org} do
      assignee = user_fixture()
      issue = issue_fixture(scope)

      {:ok, _updated} =
        VehicleIssues.update_issue(issue, %{assigned_to_id: assignee.id}, scope: scope)

      assert [notification] = notifications_for(assignee, org)
      assert notification.type == "issue_assigned"
    end

    test "resolving an issue notifies the reporter", %{scope: scope, org: org} do
      reporter = user_fixture()
      issue = seed_issue_reported_by(reporter, scope, org)

      {:ok, _resolved} = VehicleIssues.resolve_issue(issue, %{}, scope: scope)

      assert [notification] = notifications_for(reporter, org)
      assert notification.type == "issue_resolved"
      assert notification.title == "Issue ##{issue.issue_number} was resolved"
    end

    test "resolving your own issue does not notify you", %{scope: scope, org: org, owner: owner} do
      issue = issue_fixture(scope)

      {:ok, _resolved} = VehicleIssues.resolve_issue(issue, %{}, scope: scope)

      assert notifications_for(owner, org) == []
    end
  end

  defp notifications_for(user, org) do
    Notifications.list_notifications!(scope: Scope.new(user, org, false))
  end

  # Seed an issue reported by someone other than the acting owner, so lifecycle
  # transitions have a distinct reporter to notify.
  defp seed_issue_reported_by(reporter, scope, org) do
    vehicle = vehicle_fixture(scope)

    Ash.Seed.seed!(
      Fleetms.VehicleIssues.Issue,
      %{
        title: "Reported by other",
        issue_number: System.unique_integer([:positive]),
        vehicle_id: vehicle.id,
        reported_by_id: reporter.id,
        priority: :Low,
        status: :open,
        reported_at: DateTime.utc_now()
      },
      tenant: org
    )
  end
end
