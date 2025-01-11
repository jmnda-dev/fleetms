defmodule FleetmsWeb.VehicleGeneralReminderLive.FormComponent do
  use FleetmsWeb, :live_component

  @impl true
  def update(%{vehicle_general_reminder: vehicle_general_reminder} = assigns, socket) do
    socket = assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      if vehicle_general_reminder do
        AshPhoenix.Form.for_update(vehicle_general_reminder, :update,
          domain: Fleetms.VehicleManagement,
          as: "vehicle_general_reminder",
          actor: actor,
          tenant: tenant,
          forms: [
            vehicle_reminder_purpose: [
              type: :single,
              resource: Fleetms.VehicleManagement.VehicleReminderPurpose,
              data: vehicle_general_reminder.vehicle_reminder_purpose,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        AshPhoenix.Form.for_create(Fleetms.VehicleManagement.VehicleGeneralReminder, :create,
          domain: Fleetms.VehicleManagement,
          as: "vehicle_general_reminder",
          actor: actor,
          tenant: tenant,
          forms: [
            vehicle_reminder_purpose: [
              type: :single,
              resource: Fleetms.VehicleManagement.VehicleReminderPurpose,
              data: %Fleetms.VehicleManagement.VehicleReminderPurpose{},
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      end

    vehicles =
      Fleetms.VehicleManagement.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    vehicle_reminder_purposes =
      Fleetms.VehicleManagement.VehicleReminderPurpose.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.name})

    socket =
      socket
      |> assign(:form, form |> to_form())
      |> assign(:vehicles, vehicles)
      |> assign(:vehicle_reminder_purposes, vehicle_reminder_purposes)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"vehicle_general_reminder" => vehicle_general_reminder_params},
        socket
      ) do
    form = AshPhoenix.Form.validate(socket.assigns.form, vehicle_general_reminder_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event(
        "save",
        %{"vehicle_general_reminder" => vehicle_general_reminder_params},
        socket
      ) do
    save_vehicle(socket, socket.assigns.action, vehicle_general_reminder_params)
  end

  defp save_vehicle(socket, :edit, vehicle_general_reminder_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: vehicle_general_reminder_params) do
      {:ok, vehicle_general_reminder} ->
        notify_parent({:saved, vehicle_general_reminder})

        {:noreply,
         socket
         |> put_toast(:info, "Vehicle General Reminder was updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_vehicle(socket, :new, vehicle_assigmnent_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: vehicle_assigmnent_params) do
      {:ok, vehicle} ->
        notify_parent({:saved, vehicle})

        {:noreply,
         socket
         |> put_toast(:info, "Vehicle General Reminder was added successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
