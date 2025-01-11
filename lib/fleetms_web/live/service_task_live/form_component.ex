defmodule FleetmsWeb.ServiceTaskLive.FormComponent do
  use FleetmsWeb, :live_component

  @impl true
  def update(%{service_task: service_task} = assigns, socket) do
    socket =
      assign(socket, assigns)

    form =
      if service_task do
        service_task
        |> AshPhoenix.Form.for_action(:update,
          as: "service_task",
          domain: Fleetms.VehicleMaintenance,
          actor: socket.assigns.current_user,
          tenant: socket.assigns.tenant,
          forms: [auto?: true]
        )
      else
        Fleetms.VehicleMaintenance.ServiceTask
        |> AshPhoenix.Form.for_create(:create,
          as: "service_task",
          domain: Fleetms.VehicleMaintenance,
          actor: socket.assigns.current_user,
          tenant: socket.assigns.tenant,
          forms: [auto?: true]
        )
      end

    {:ok, assign(socket, :form, form |> to_form())}
  end

  @impl true
  def handle_event("validate", %{"service_task" => service_task_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, service_task_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"service_task" => service_task_params}, socket) do
    save_service_task(socket, socket.assigns.action, service_task_params)
  end

  defp save_service_task(socket, :edit, service_task_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: service_task_params) do
      {:ok, service_task} ->
        notify_parent({:saved, service_task})

        {:noreply,
         socket
         |> put_toast(:info, "Service Task updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_service_task(socket, :new, service_task_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: service_task_params) do
      {:ok, service_task} ->
        notify_parent({:saved, service_task})

        {:noreply,
         socket
         |> put_toast(:info, "Service Task created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
