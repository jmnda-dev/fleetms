defmodule FleetmsWeb.PartLive.Detail do
  use FleetmsWeb, :live_view
  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :inventory_module}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket, :active_link, :parts_and_inventory)
      |> assign(:active_tab, :photos)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(
        :part,
        Fleetms.Inventory.Part.get_by_id!(id, tenant: tenant, actor: actor)
      )

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_event("show_tab", %{"tab" => "photos"}, socket) do
    {:noreply, assign(socket, :active_tab, :photos)}
  end

  @impl true
  def handle_event("show_tab", %{"tab" => "part_inventory_locations"}, socket) do
    {:noreply, assign(socket, :active_tab, :part_inventory_locations)}
  end

  defp apply_action(socket, :edit, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Inventory.Part, :update},
        socket.assigns.current_user
      )

    if can_perform_action? do
      socket
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :detail, _params) do
    assign(socket, :page_title, "Listing Parts")
  end

  defp page_title(:detail), do: "Show Part"
  defp page_title(:edit), do: "Edit Part"
end
