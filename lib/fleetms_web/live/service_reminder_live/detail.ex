defmodule FleetmsWeb.ServiceReminderLive.Detail do
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :service_reminders)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Service.ServiceReminder, :update}, actor)

    if live_action == :edit and not can_perform_action? do
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:page_title, page_title(live_action))
       |> assign(
         :service_reminder,
         Fleetms.Service.ServiceReminder.get_by_id!(id, tenant: tenant, actor: actor)
       )}
    end
  end

  defp page_title(:detail), do: "Show Service Reminder"
  defp page_title(:edit), do: "Edit Service Reminder"
end
