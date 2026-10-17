defmodule Fleetms.VehicleIssues.Issue.Changes.NotifyAssignee do
  @moduledoc """
  When an issue is assigned to a member (on create, or when `assigned_to_id`
  changes on update), send them an in-app notification — the first producer for
  the notifications bell.

  Runs only when the assignee actually changed and isn't the acting user (nobody
  needs to be told they assigned an issue to themselves). Creation is best-effort:
  a failure here must not roll back the issue, so it runs after the transaction.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn
      changeset, {:ok, issue} ->
        notify_assignee(changeset, issue, context)
        {:ok, issue}

      _changeset, other ->
        other
    end)
  end

  defp notify_assignee(changeset, issue, context) do
    assignee_id = issue.assigned_to_id
    actor_id = context.actor && context.actor.id

    if Ash.Changeset.changing_attribute?(changeset, :assigned_to_id) and
         not is_nil(assignee_id) and assignee_id != actor_id do
      Fleetms.Notifications.notify_if_subscribed(
        %{
          recipient_id: assignee_id,
          actor_id: actor_id,
          type: "issue_assigned",
          title: "You were assigned issue ##{issue.issue_number}",
          body: issue.title,
          path: "/issues/#{issue.id}"
        },
        tenant: context.tenant,
        authorize?: false
      )
    end

    :ok
  end
end
