defmodule Fleetms.VehicleIssues.Issue.Changes.NotifyIssueLifecycle do
  @moduledoc """
  Notifies the member who opened an issue, plus anyone watching it, when the issue
  is resolved or closed.

  Attach with an `:event` option (`:resolved` or `:closed`), which drives the
  notification's copy and icon type. The acting user is never notified (they made
  the change), and each recipient is notified once even if they both reported and
  watch the issue. Best-effort: runs after the transaction so a notification
  failure can't roll back the lifecycle transition.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def init(opts) do
    case opts[:event] do
      event when event in [:resolved, :closed] -> {:ok, opts}
      _ -> {:error, "event must be :resolved or :closed"}
    end
  end

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, issue} ->
        notify_followers(issue, opts[:event], context)
        {:ok, issue}

      _changeset, other ->
        other
    end)
  end

  defp notify_followers(issue, event, context) do
    actor_id = context.actor && context.actor.id

    recipient_ids =
      [issue.reported_by_id | watcher_ids(issue, context)]
      |> Enum.reject(&(is_nil(&1) or &1 == actor_id))
      |> Enum.uniq()

    for recipient_id <- recipient_ids do
      Fleetms.Notifications.notify_if_subscribed(
        %{
          recipient_id: recipient_id,
          actor_id: actor_id,
          type: "issue_#{event}",
          title: "Issue ##{issue.issue_number} was #{event}",
          body: issue.title,
          path: "/issues/#{issue.id}"
        },
        tenant: context.tenant,
        authorize?: false
      )
    end

    :ok
  end

  defp watcher_ids(issue, context) do
    Fleetms.VehicleIssues.IssueWatcher
    |> Ash.Query.filter(issue_id == ^issue.id)
    |> Ash.read!(tenant: context.tenant, authorize?: false)
    |> Enum.map(& &1.user_id)
  end
end
