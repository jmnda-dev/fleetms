defmodule FleetmsWeb.LiveNotifications do
  @moduledoc """
  Keeps the navbar bell live on every tenant-scoped page.

  Mounted after `:require_organization` (which resolves `current_scope` in a
  `handle_params` hook), this attaches its own `handle_params` hook that — once a
  scope is available — subscribes to the recipient's per-organization PubSub topic
  and loads the initial badge count and recent list. A `:notifications_changed`
  signal (broadcast whenever a notification is created) triggers a reload, and the
  bell's own events (`mark-all-read`, opening an item) are handled here too, so no
  individual LiveView needs to know about notifications.

  Producers store an **org-relative** `path` (e.g. `"/issues/<id>"`); the open
  handler prefixes it with the current `/o/<public_id>` scope, since a recipient
  only ever views notifications from within the org they belong to.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  alias Fleetms.Notifications
  alias Fleetms.Scope

  @recent_limit 10

  def on_mount(:notifications, _params, _session, socket) do
    socket =
      socket
      |> assign(unread_notifications_count: 0, recent_notifications: [])
      |> assign(notifications_open: false, notifications_ready?: false)
      |> attach_hook(:setup_notifications, :handle_params, &setup/3)
      |> attach_hook(:notifications_info, :handle_info, &handle_info/2)
      |> attach_hook(:notifications_event, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  # Runs after `resolve_organization` has set `current_scope`. Subscribe + load
  # once per socket (the connected mount re-runs this on a fresh socket).
  defp setup(_params, _uri, socket) do
    scope = socket.assigns[:current_scope]

    if socket.assigns.notifications_ready? or not scoped?(scope) do
      {:cont, socket}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(
          Fleetms.PubSub,
          Notifications.topic(scope.organization, scope.user.id)
        )
      end

      {:cont, socket |> assign(:notifications_ready?, true) |> load(scope)}
    end
  end

  defp handle_info(:notifications_changed, socket) do
    {:halt, load(socket, socket.assigns.current_scope)}
  end

  defp handle_info(_message, socket), do: {:cont, socket}

  defp handle_event("notifications:toggle", _params, socket) do
    {:halt, assign(socket, :notifications_open, not socket.assigns.notifications_open)}
  end

  defp handle_event("notifications:close", _params, socket) do
    {:halt, assign(socket, :notifications_open, false)}
  end

  defp handle_event("notifications:mark-all-read", _params, socket) do
    scope = socket.assigns.current_scope
    Notifications.mark_all_notifications_read!(scope: scope)
    {:halt, load(socket, scope)}
  end

  defp handle_event("notifications:open", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Notifications.get_notification(id, scope: scope) do
      {:ok, notification} ->
        Notifications.mark_notification_read!(notification, scope: scope)
        socket = socket |> assign(:notifications_open, false) |> load(scope)
        {:halt, maybe_navigate(socket, scope, notification.path)}

      _error ->
        {:halt, socket}
    end
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  defp maybe_navigate(socket, _scope, path) when path in [nil, ""], do: socket

  defp maybe_navigate(socket, scope, path) do
    push_navigate(socket, to: "/o/#{scope.organization.public_id}#{path}")
  end

  defp load(socket, scope) do
    assign(socket,
      unread_notifications_count: Notifications.unread_notification_count!(scope: scope),
      recent_notifications:
        Notifications.list_notifications!(scope: scope, query: [limit: @recent_limit])
    )
  end

  defp scoped?(%Scope{user: %{}, organization: %{}}), do: true
  defp scoped?(_scope), do: false
end
