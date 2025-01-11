defmodule FleetmsWeb.FuelHistoryLive.Detail do
  use FleetmsWeb, :live_view

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :fuel_tracking_module}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :fuel_histories)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns
    fuel_history = Fleetms.FuelManagement.FuelHistory.get_by_id!(id, tenant: tenant, actor: actor)

    can_perform_action? =
      Ash.can?(
        {fuel_history, :update},
        actor
      )

    if live_action == :edit and not can_perform_action? do
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:fuel_history, fuel_history)}
  end

  defp page_title(:detail), do: "Fuel History Details"
  defp page_title(:edit), do: "Edit Fuel History"
end
