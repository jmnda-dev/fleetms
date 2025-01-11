defmodule FleetmsWeb.ServiceGroupLive.Index do
  use FleetmsWeb, :live_view

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :service_module}

  @impl true
  def mount(_params, _session, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    service_groups = list_service_groups(tenant, actor)

    socket =
      socket
      |> assign(:active_link, :service_groups)
      |> stream(:service_groups, service_groups.results)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.VehicleMaintenance.ServiceGroup, :update}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Edit Service Group")
      |> assign(
        :service_group,
        Fleetms.VehicleMaintenance.ServiceGroup.get_by_id!(id, tenant: tenant, actor: actor)
      )
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :new, _params) do
    actor = socket.assigns.current_user

    can_perform_action? =
      Ash.can?({Fleetms.VehicleMaintenance.ServiceGroup, :create}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "New Service Group")
      |> assign(:service_group, nil)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Service Groups")
    |> assign(:service_group, nil)
  end

  @impl true
  def handle_info({FleetmsWeb.ServiceGroupLive.FormComponent, {:saved, service_group}}, socket) do
    {:noreply, stream_insert(socket, :service_groups, service_group)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.VehicleMaintenance.ServiceGroup, :destroy}, actor)

    if can_perform_action? do
      service_group = Fleetms.VehicleMaintenance.ServiceGroup.get_by_id!(id, tenant: tenant, actor: actor)

      Ash.destroy!(service_group, tenant: tenant, actor: actor)

      socket =
        socket
        |> stream_delete(:service_groups, service_group)
        |> put_toast(:info, "#{service_group.name} was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp list_service_groups(tenant, actor) do
    Fleetms.VehicleMaintenance.ServiceGroup
    |> Ash.Query.for_read(:list)
    |> Ash.read!(tenant: tenant, actor: actor)
  end
end
