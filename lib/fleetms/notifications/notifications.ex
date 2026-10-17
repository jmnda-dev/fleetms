defmodule Fleetms.Notifications do
  @moduledoc """
  In-app notifications: per-member messages within an organization, delivered to
  the navbar bell in real time over Phoenix PubSub.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/notifications", Fleetms.Notifications.Notification do
        index :list
        get(:get_by_id)
        patch(:mark_read, route: "/:id/read")
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.Notifications.Notification do
      define :list_notifications, action: :list
      define :list_unread_notifications, action: :list_unread
      define :get_notification, action: :get_by_id, args: [:id]
      define :notify, action: :notify
      define :mark_notification_read, action: :mark_read
      define :mark_all_notifications_read, action: :mark_all_read
      define :unread_notification_count, action: :unread_count
      define :delete_notification, action: :destroy
    end

    resource Fleetms.Notifications.NotificationPreference do
      define :get_notification_preference, action: :get_for_user, args: [:user_id]
      define :upsert_notification_preference, action: :upsert
    end
  end

  @doc """
  The notification categories a member can mute, each with a label for the settings
  UI. The keys match the boolean attributes on `NotificationPreference`.
  """
  def categories do
    [
      issues: "Issues",
      comments: "Comments & mentions",
      inspections: "Inspections"
    ]
  end

  @doc """
  Creates an in-app notification, unless the recipient has muted the category the
  notification's `type` belongs to. Call this instead of `notify/2` from producers
  so member preferences are respected. `opts` must carry the `:tenant` (and usually
  `authorize?: false`, since producers run as the system).

  Returns `{:ok, notification}`, `{:ok, :skipped}` when muted, or an error tuple.
  """
  def notify_if_subscribed(attrs, opts) do
    type = attrs[:type] || attrs["type"]
    recipient_id = attrs[:recipient_id] || attrs["recipient_id"]

    case category_for(type) do
      nil ->
        notify(attrs, opts)

      category ->
        if subscribed?(recipient_id, category, opts),
          do: notify(attrs, opts),
          else: {:ok, :skipped}
    end
  end

  # Maps a notification `type` (e.g. "issue_assigned", "comment_mention",
  # "inspection_workflow") to a mutable category, or nil for always-on types.
  defp category_for(type) when is_atom(type), do: category_for(to_string(type))

  defp category_for("issue" <> _), do: :issues
  defp category_for("comment" <> _), do: :comments
  defp category_for("mention" <> _), do: :comments
  defp category_for("inspection" <> _), do: :inspections
  defp category_for(_), do: nil

  # A missing preference row means "subscribed to everything".
  defp subscribed?(nil, _category, _opts), do: true

  defp subscribed?(recipient_id, category, opts) do
    lookup_opts = Keyword.take(opts, [:tenant]) ++ [authorize?: false]

    case get_notification_preference(recipient_id, lookup_opts) do
      {:ok, %{} = pref} -> Map.get(pref, category, true)
      _ -> true
    end
  end

  @doc """
  The PubSub topic a recipient's notifications are broadcast on, scoped to the
  organization (tenant). Pass the tenant as set on the action (`org_<id>` string)
  or an `Organization`; both resolve to the same topic.
  """
  @spec topic(String.t() | struct(), Ecto.UUID.t()) :: String.t()
  def topic(tenant, recipient_id) when is_binary(tenant) do
    "notifications:#{tenant}:#{recipient_id}"
  end

  def topic(tenant, recipient_id) do
    topic(Ash.ToTenant.to_tenant(tenant, Fleetms.Notifications.Notification), recipient_id)
  end
end
