defmodule FleetmsWeb.InventoryLocationLive.Detail do
  use FleetmsWeb, :live_view

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :inventory_module}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_link, :inventory_locations)
      |> assign(:total, 0)
      |> assign(:total_pages, 0)
      |> assign(:search_params, %{search_query: ""})
      |> assign(:has_more?, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(
        :inventory_location,
        Fleetms.Inventory.InventoryLocation.get_by_id!(id, tenant: tenant, actor: actor)
      )

    {:noreply, apply_action(socket, live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Inventory.InventoryLocation, :update},
        socket.assigns.current_user
      )

    if can_perform_action? do
      socket
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :detail, _params), do: socket

  defp page_title(:detail), do: "Inventory Location Detail"
  defp page_title(:edit), do: "Edit Inventory Location"
end
