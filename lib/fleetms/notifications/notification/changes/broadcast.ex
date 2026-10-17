defmodule Fleetms.Notifications.Notification.Changes.Broadcast do
  @moduledoc """
  After a notification is created, broadcast a lightweight `:notifications_changed`
  signal on the recipient's per-organization topic. The subscribed LiveView reloads
  its unread count and recent list from the (tenant-scoped) database, so the same
  signal covers creation and any later read/clear from another tab.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, notification ->
      topic = Fleetms.Notifications.topic(context.tenant, notification.recipient_id)
      Phoenix.PubSub.broadcast(Fleetms.PubSub, topic, :notifications_changed)
      {:ok, notification}
    end)
  end
end
