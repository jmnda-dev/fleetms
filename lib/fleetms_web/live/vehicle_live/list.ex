defmodule FleetmsWeb.VehicleLive.List do
  use FleetmsWeb, :live_view

  alias Fleetms.Vehicles
  alias Fleetms.Vehicles.Vehicle

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if Ash.can?({Vehicle, :list}, socket.assigns.current_user) do
      {:ok, socket}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError, "Unauthorized action"
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    %{current_user: current_user} = socket.assigns
    vehicles = Vehicles.list_vehicles!(tenant: current_user.organization, actor: current_user)

    socket = stream(socket, :vehicles, vehicles)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :listing, _params) do
    socket
    |> assign(:page_title, "User Listing")
    |> assign(:vehicle, nil)
  end
end
