defmodule FleetmsWeb.VehicleLive.DocumentList do
  use FleetmsWeb, :live_view

  alias Fleetms.VehicleManagement
  alias VehicleManagement.Vehicle

  # alias FleetmsWeb.LiveUserAuth
  #
  # on_mount {LiveUserAuth, :vehicles_module}

  def mount(%{"id" => id}, _session, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    vehicle = Vehicle.get_by_id!(id, tenant: tenant, actor: actor)
    documents = VehicleManagement.list_documents_by_vehicle!(id, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream(:documents, documents)
      |> assign(:vehicle, vehicle)
      |> assign(:active_link, :vehicles)

    {:ok, socket}
  end

  def handle_event("download", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    document = VehicleManagement.get_document_by_id!(id, tenant: tenant, actor: actor)

    if document.vehicle_id == socket.assigns.vehicle.id do
      {:noreply,
       push_navigate(socket,
         to: ~p"/vehicles/documents/download/#{document}"
       )}
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    document = VehicleManagement.get_document_by_id!(id, tenant: tenant, actor: actor)

    if document.vehicle_id == socket.assigns.vehicle.id do
      Ash.destroy!(document, tenant: tenant, actor: actor)

      socket =
        socket
        |> stream_delete(:documents, document)
        |> put_toast(:info, "Document was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end
end
