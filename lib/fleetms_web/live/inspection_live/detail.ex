defmodule FleetmsWeb.InspectionLive.Detail do
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :inspection_submissions)}
  end

  @impl true
  def handle_params(%{"id" => id} = _params, _uri, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    inspection =
      Fleetms.Inspection.InspectionSubmission.get_by_id!(id, tenant: tenant, actor: actor)

    {:noreply, assign(socket, inspection: inspection)}
  end
end
