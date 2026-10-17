defmodule FleetmsWeb.NotificationLive.Index do
  @moduledoc """
  The full notifications list — the bell dropdown's "See all" destination.

  Shows the recipient's notifications newest-first with read/unread styling,
  lets them open one (marks it read, then follows its link), mark everything
  read, or clear a single notification. Each mutation broadcasts
  `:notifications_changed` so the navbar bell (kept live by
  `FleetmsWeb.LiveNotifications`) stays in sync, here and in other tabs.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Notifications

  @limit 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Notifications"), active_link: :notifications)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_page(socket, page_number(params["page"]))}
  end

  defp load_page(socket, page) do
    scope = socket.assigns.current_scope
    offset = (page - 1) * @limit

    # Fetch one extra to know whether a next page exists (the action isn't paginated).
    rows =
      Notifications.list_notifications!(scope: scope, query: [limit: @limit + 1, offset: offset])

    assign(socket,
      notifications: Enum.take(rows, @limit),
      page: page,
      has_more: length(rows) > @limit
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      organizations={@organizations}
      unread_notifications_count={@unread_notifications_count}
      recent_notifications={@recent_notifications}
      notifications_open={@notifications_open}
    >
      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Notifications")}
      ]} />

      <.header>
        {gettext("Notifications")}
        <:subtitle>{gettext("Everything you've been notified about, newest first.")}</:subtitle>
        <:actions>
          <.button
            :if={@unread_notifications_count > 0}
            variant="secondary"
            phx-click="mark_all"
          >
            <.icon name="fa-check-double" class="me-2" /> {gettext("Mark all read")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div :if={@notifications == []} class="px-4 py-6">
          <.empty_state
            icon="fa-bell"
            title={gettext("No notifications")}
            message={gettext("When something needs your attention, it'll show up here.")}
          />
        </div>

        <ul class="divide-y divide-default">
          <li
            :for={notification <- @notifications}
            class={[
              "flex items-start gap-3 px-4 py-3",
              is_nil(notification.read_at) && "bg-primary-50/60 dark:bg-gray-700/40"
            ]}
          >
            <span class="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-300">
              <i class={["fa-solid text-sm", notification_icon(notification.type)]}></i>
            </span>

            <button
              type="button"
              phx-click="open"
              phx-value-id={notification.id}
              class="min-w-0 flex-1 text-left"
            >
              <span class="block text-sm font-medium text-heading">{notification.title}</span>
              <span :if={notification.body not in [nil, ""]} class="block text-sm text-body">
                {notification.body}
              </span>
              <span class="mt-0.5 block text-xs text-gray-400 dark:text-gray-500">
                {time_ago(notification.inserted_at)}
              </span>
            </button>

            <span
              :if={is_nil(notification.read_at)}
              class="mt-2 h-2 w-2 shrink-0 rounded-full bg-primary-500"
              aria-hidden="true"
            >
            </span>
            <button
              type="button"
              phx-click="delete"
              phx-value-id={notification.id}
              class="shrink-0 rounded-lg p-1.5 text-gray-400 hover:bg-gray-100 hover:text-gray-600 dark:hover:bg-gray-700"
              aria-label={gettext("Clear")}
            >
              <.icon name="fa-xmark" />
            </button>
          </li>
        </ul>

        <div
          :if={@page > 1 or @has_more}
          class="flex items-center justify-between border-t border-default px-4 py-3"
        >
          <.button
            :if={@page > 1}
            size="sm"
            variant="secondary"
            navigate={page_path(assigns, @page - 1)}
          >
            <.icon name="fa-chevron-left" class="me-1 text-xs" /> {gettext("Newer")}
          </.button>
          <span :if={@page <= 1}></span>
          <.button
            :if={@has_more}
            size="sm"
            variant="secondary"
            navigate={page_path(assigns, @page + 1)}
          >
            {gettext("Older")} <.icon name="fa-chevron-right" class="ms-1 text-xs" />
          </.button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("open", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Notifications.get_notification(id, scope: scope) do
      {:ok, notification} ->
        Notifications.mark_notification_read!(notification, scope: scope)
        broadcast_changed(scope)

        if notification.path in [nil, ""] do
          {:noreply, load_page(socket, socket.assigns.page)}
        else
          {:noreply,
           push_navigate(socket, to: "/o/#{scope.organization.public_id}#{notification.path}")}
        end

      _error ->
        {:noreply, put_flash(socket, :error, gettext("That notification could not be found."))}
    end
  end

  def handle_event("mark_all", _params, socket) do
    scope = socket.assigns.current_scope
    Notifications.mark_all_notifications_read!(scope: scope)
    broadcast_changed(scope)
    {:noreply, load_page(socket, socket.assigns.page)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, notification} <- Notifications.get_notification(id, scope: scope),
         :ok <- Notifications.delete_notification(notification, scope: scope) do
      broadcast_changed(scope)
      {:noreply, load_page(socket, socket.assigns.page)}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not clear that notification."))}
    end
  end

  # Nudge the navbar bell (and other tabs) to reload from the database.
  defp broadcast_changed(scope) do
    Phoenix.PubSub.broadcast(
      Fleetms.PubSub,
      Notifications.topic(scope.organization, scope.user.id),
      :notifications_changed
    )
  end

  defp page_number(nil), do: 1

  defp page_number(value) do
    case Integer.parse(value) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp page_path(assigns, page),
    do: ~p"/o/#{org(assigns)}/notifications?#{%{"page" => page}}"

  defp notification_icon("issue_assigned"), do: "fa-user-tag"
  defp notification_icon("issue_resolved"), do: "fa-circle-check"
  defp notification_icon("issue_closed"), do: "fa-circle-xmark"
  defp notification_icon(_type), do: "fa-bell"

  defp time_ago(nil), do: ""

  defp time_ago(%DateTime{} = datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      seconds < 60 -> gettext("just now")
      seconds < 3600 -> gettext("%{n}m ago", n: div(seconds, 60))
      seconds < 86_400 -> gettext("%{n}h ago", n: div(seconds, 3600))
      seconds < 604_800 -> gettext("%{n}d ago", n: div(seconds, 86_400))
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  defp org(assigns), do: assigns.current_scope.organization
end
