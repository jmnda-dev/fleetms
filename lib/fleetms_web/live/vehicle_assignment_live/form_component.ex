defmodule FleetmsWeb.VehicleAssignmentLive.FormComponent do
  use FleetmsWeb, :live_component

  alias Fleetms.Accounts
  @impl true
  def update(%{vehicle_assignment: vehicle_assignment} = assigns, socket) do
    socket = assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      if vehicle_assignment do
        AshPhoenix.Form.for_update(vehicle_assignment, :update,
          domain: Fleetms.Vehicles,
          as: "vehicle_assignment",
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      else
        AshPhoenix.Form.for_create(Fleetms.Vehicles.VehicleAssignment, :create,
          domain: Fleetms.Vehicles,
          as: "vehicle_assignment",
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      end

    vehicles =
      Fleetms.Vehicles.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    users =
      Accounts.get_all_users!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.user_profile.full_name, &1.id})

    socket =
      socket
      |> assign(:form, form |> to_form())
      |> assign(:vehicles, vehicles)
      |> assign(:users, users)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"vehicle_assignment" => vehicle_assignment_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, vehicle_assignment_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"vehicle_assignment" => vehicle_assignment_params}, socket) do
    save_vehicle(socket, socket.assigns.action, vehicle_assignment_params)
  end

  defp save_vehicle(socket, :edit, vehicle_assignment_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: vehicle_assignment_params) do
      {:ok, vehicle_assignment} ->
        notify_parent({:saved, vehicle_assignment})

        {:noreply,
         socket
         |> put_flash(:info, "Vehicle Assignment was updated successfully")
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
         |> put_flash(:info, "Vehicle Assignment was added successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
