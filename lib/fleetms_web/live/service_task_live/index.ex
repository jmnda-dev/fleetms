defmodule FleetmsWeb.ServiceTaskLive.Index do
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    service_tasks = list_service_tasks(tenant, actor)

    socket =
      socket
      |> assign(:active_link, :service_tasks)
      |> stream(:service_tasks, service_tasks.results)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Service.ServiceTask, :update}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Edit Service Task")
      |> assign(
        :service_task,
        Fleetms.Service.ServiceTask.get_by_id!(id, tenant: tenant, actor: actor)
      )
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :new, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Service.ServiceTask, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      socket
      |> assign(:page_title, "New Service Task")
      |> assign(:service_task, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Service Tasks")
    |> assign(:service_task, nil)
  end

  @impl true
  def handle_info({FleetmsWeb.ServiceTaskLive.FormComponent, {:saved, service_task}}, socket) do
    {:noreply, stream_insert(socket, :service_tasks, service_task)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Service.ServiceTask, :destroy}, actor)

    if can_perform_action? do
      service_task = Fleetms.Service.ServiceTask.get_by_id!(id, tenant: tenant, actor: actor)

      Ash.destroy!(service_task, tenant: tenant, actor: actor)

      socket =
        socket
        |> stream_delete(:service_tasks, service_task)
        |> put_flash(:info, "Service task was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp list_service_tasks(tenant, actor) do
    Fleetms.Service.ServiceTask
    |> Ash.Query.for_read(:list)
    |> Ash.read!(tenant: tenant, actor: actor)
  end
end
