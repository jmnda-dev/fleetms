defmodule Fleetms.Comments.CommentTest do
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures
  import Fleetms.IssueFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.AccountsFixtures

  alias Fleetms.Comments
  alias Fleetms.Notifications
  alias Fleetms.Scope

  setup :shared_org

  # Only the comment-produced notifications, so a pre-existing "issue_assigned" from
  # creating the issue doesn't get counted.
  defp comment_notifications(user, org) do
    Notifications.list_notifications!(scope: Scope.new(user, org, false))
    |> Enum.filter(&(&1.type in ["comment", "comment_mention"]))
  end

  describe "posting and listing" do
    test "a comment is posted and listed back with its author", %{scope: scope} do
      issue = issue_fixture(scope)

      {:ok, comment} =
        Comments.create_comment(%{body: "Looks serious", issue_id: issue.id}, scope: scope)

      assert [listed] = Comments.list_comments!(%{issue_id: issue.id}, scope: scope)
      assert listed.id == comment.id
      assert listed.body == "Looks serious"
      assert listed.author_id == scope.user.id
    end

    test "a parent only lists its own comments", %{scope: scope} do
      one = issue_fixture(scope)
      two = issue_fixture(scope)
      {:ok, _} = Comments.create_comment(%{body: "on one", issue_id: one.id}, scope: scope)
      {:ok, _} = Comments.create_comment(%{body: "on two", issue_id: two.id}, scope: scope)

      assert [%{body: "on one"}] = Comments.list_comments!(%{issue_id: one.id}, scope: scope)
    end
  end

  describe "exactly-one-parent constraint" do
    test "a comment with no parent is rejected", %{scope: scope} do
      assert {:error, _} = Comments.create_comment(%{body: "orphan"}, scope: scope)
    end

    test "a comment with two parents is rejected", %{scope: scope} do
      issue = issue_fixture(scope)
      work_order = work_order_fixture(scope)

      assert {:error, _} =
               Comments.create_comment(
                 %{body: "both", issue_id: issue.id, work_order_id: work_order.id},
                 scope: scope
               )
    end
  end

  describe "notifications" do
    test "mentioning a member notifies them", %{scope: scope, org: org} do
      mentioned = user_fixture()
      issue = issue_fixture(scope)

      {:ok, _} =
        Comments.create_comment(
          %{body: "take a look", issue_id: issue.id, mentioned_user_ids: [mentioned.id]},
          scope: scope
        )

      assert [n] = comment_notifications(mentioned, org)
      assert n.type == "comment_mention"
      assert n.title =~ "mentioned you on issue ##{issue.issue_number}"
      assert n.path == "/issues/#{issue.id}"
    end

    test "the issue's assignee is notified as a participant", %{scope: scope, org: org} do
      assignee = user_fixture()
      issue = issue_fixture(scope, %{assigned_to_id: assignee.id})

      {:ok, _} = Comments.create_comment(%{body: "fyi", issue_id: issue.id}, scope: scope)

      assert [n] = comment_notifications(assignee, org)
      assert n.type == "comment"
      assert n.title =~ "commented on issue ##{issue.issue_number}"
    end

    test "the author is never notified about their own comment", %{
      scope: scope,
      org: org,
      owner: owner
    } do
      # The owner is the issue's reporter (a participant) AND the comment's author.
      issue = issue_fixture(scope)
      {:ok, _} = Comments.create_comment(%{body: "mine", issue_id: issue.id}, scope: scope)

      assert comment_notifications(owner, org) == []
    end

    test "a mentioned participant gets a single mention notification", %{scope: scope, org: org} do
      assignee = user_fixture()
      issue = issue_fixture(scope, %{assigned_to_id: assignee.id})

      {:ok, _} =
        Comments.create_comment(
          %{body: "@you please check", issue_id: issue.id, mentioned_user_ids: [assignee.id]},
          scope: scope
        )

      assert [n] = comment_notifications(assignee, org)
      assert n.type == "comment_mention"
    end

    test "a comment on a vehicle reaches mentions only (no participants)", %{
      scope: scope,
      org: org
    } do
      mentioned = user_fixture()
      vehicle = vehicle_fixture(scope, %{name: "Notify Rig"})

      {:ok, _} =
        Comments.create_comment(
          %{body: "check tyres", vehicle_id: vehicle.id, mentioned_user_ids: [mentioned.id]},
          scope: scope
        )

      assert [n] = comment_notifications(mentioned, org)
      assert n.type == "comment_mention"
      assert n.title =~ "mentioned you on Notify Rig"
    end
  end
end
