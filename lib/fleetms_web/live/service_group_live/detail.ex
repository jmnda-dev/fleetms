defmodule FleetmsWeb.ServiceGroupLive.Detail do
  use FleetmsWeb, :live_view

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :service_module}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :service_groups)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:page_title, page_title(live_action))
      |> assign(
        :service_group,
        Fleetms.VehicleMaintenance.ServiceGroup.get_by_id!(id, tenant: tenant, actor: actor)
      )

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_event("delete_schedule", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    service_group_schedule =
      Fleetms.VehicleMaintenance.ServiceGroupSchedule.get_by_id!(id, tenant: tenant, actor: actor)

    Ash.destroy!(service_group_schedule, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream_delete(:service_group_schedules, service_group_schedule)
      |> put_toast(:info, "The Schedule was deleted successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {FleetmsWeb.ServiceGroupLive.ScheduleFormComponent, {:saved, service_group_schedule}},
        socket
      ) do
    {:noreply, stream_insert(socket, :service_group_schedules, service_group_schedule)}
  end

  @impl true
  def handle_info(
        {FleetmsWeb.ServiceGroupLive.ScheduleFormComponent, {:deleted, service_group_schedule}},
        socket
      ) do
    {:noreply, stream_delete(socket, :service_group_schedules, service_group_schedule)}
  end

  defp apply_action(socket, :edit, _params) do
    actor = socket.assigns.current_user

    can_perform_action? =
      Ash.can?({Fleetms.VehicleMaintenance.ServiceGroup, :update}, actor)

    if can_perform_action? do
      socket
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :detail, _params) do
    assign(socket, :page_title, "Listing Service Groups")
    |> assign(:service_group_schedule, nil)
  end

  defp apply_action(socket, :service_group_schedules, _params) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    service_group = socket.assigns.service_group

    service_group_schedules =
      Fleetms.VehicleMaintenance.ServiceGroupSchedule.get_service_group_schedules!(service_group.id,
        tenant: tenant,
        actor: actor
      )

    stream(socket, :service_group_schedules, service_group_schedules.results)
  end

  defp apply_action(socket, :add_service_group_schedule, _params) do
    actor = socket.assigns.current_user

    can_perform_action? =
      Ash.can?({Fleetms.VehicleMaintenance.ServiceGroupSchedule, :create}, actor)

    if can_perform_action? do
      assign(socket, :service_group_schedule, nil)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(
         socket,
         :edit_service_group_schedule,
         %{"service_group_schedule_id" => id} = _params
       ) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.VehicleMaintenance.ServiceGroupSchedule, :update}, actor)

    if can_perform_action? do
      service_group_schedule =
        Fleetms.VehicleMaintenance.ServiceGroupSchedule.get_by_id!(id, tenant: tenant, actor: actor)

      assign(socket, :service_group_schedule, service_group_schedule)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :vehicles, _params) do
    service_group = socket.assigns.service_group
    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicles =
      Fleetms.VehicleManagement.Vehicle.get_service_group_vehicles!(service_group.id,
        tenant: tenant,
        actor: actor
      )

    stream(socket, :vehicles, vehicles.results)
  end

  defp page_title(:detail), do: "Show ServiceGroup"
  defp page_title(:edit), do: "Edit ServiceGroup"
  defp page_title(:service_group_schedules), do: "Service Group Schedules"
  defp page_title(:add_service_group_schedule), do: "Add Service Group Schedule"
  defp page_title(:edit_service_group_schedule), do: "Edit Service Group Schedule"
  defp page_title(:vehicles), do: "Service Group Vehicles"
end
