defmodule FleetmsWeb.VehicleLive.Detail do
  use FleetmsWeb, :live_view

  @impl true
  def handle_params(%{"id" => id} = _params, _uri, socket) do
    %{live_action: live_action, tenant: tenant, current_user: actor} = socket.assigns

    if live_action == :edit do
      can_perform_action? =
        Ash.can?(
          {Fleetms.Vehicles.Vehicle, :update},
          actor
        )

      if not can_perform_action? do
        raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
              "You are not authorized to perform this action"
      end
    end

    vehicle = Fleetms.Vehicles.Vehicle.get_by_id!(id, tenant: tenant, actor: actor)

    socket =
      assign(socket, :vehicle, vehicle)
      |> assign(:active_link, :vehicles)
      |> assign(:page_title, page_title(live_action))

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "selected_vehicle_make",
        %{"vehicle_make" => vehicle_make},
        socket
      ) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicle_models =
      Fleetms.Vehicles.VehicleModel.list_by_vehicle_make!(vehicle_make,
        tenant: tenant,
        actor: actor
      )

    send_update(FleetmsWeb.VehicleLive.FormComponent,
      id: "vehicle-form-component",
      vehicle_models: vehicle_models
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => _id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    Ash.destroy!(socket.assigns.vehicle, tenant: tenant, actor: actor)

    socket =
      socket
      |> put_flash(:info, "Vehicle was deleted successfully")
      |> push_navigate(to: ~p"/vehicles")

    {:noreply, socket}
  end

  defp page_title(:detail), do: "Vehicle Details"
  defp page_title(:edit), do: "Edit Vehicle Details"
  defp page_title(:vehicle_issues), do: "Vehicle Issues"
  defp page_title(:vehicle_service_reminders), do: "Vehicle Service Reminders"
  defp page_title(:vehicle_work_orders), do: "Vehicle Work Orders"
  defp page_title(:vehicle_fuel_histories), do: "Vehicle Fuel Histories"
end
