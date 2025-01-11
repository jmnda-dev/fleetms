defmodule FleetmsWeb.ServiceReminderLive.Detail do
  use FleetmsWeb, :live_view

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :service_module}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :service_reminders)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.VehicleMaintenance.ServiceReminder, :update}, actor)

    if live_action == :edit and not can_perform_action? do
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:page_title, page_title(live_action))
       |> assign(
         :service_reminder,
         Fleetms.VehicleMaintenance.ServiceReminder.get_by_id!(id, tenant: tenant, actor: actor)
       )}
    end
  end

  defp page_title(:detail), do: "Show Service Reminder"
  defp page_title(:edit), do: "Edit Service Reminder"
end
