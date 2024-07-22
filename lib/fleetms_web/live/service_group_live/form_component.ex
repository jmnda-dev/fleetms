defmodule FleetmsWeb.ServiceGroupLive.FormComponent do
  use FleetmsWeb, :live_component

  @impl true
  def update(%{service_group: service_group} = assigns, socket) do
    socket =
      assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    service_group =
      service_group
      |> Ash.load!(:vehicles, tenant: tenant, actor: actor)

    form =
      if service_group do
        service_group
        |> AshPhoenix.Form.for_action(:update,
          as: "service_group",
          domain: Fleetms.Service,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      else
        Fleetms.Service.ServiceGroup
        |> AshPhoenix.Form.for_create(:create,
          as: "service_group",
          domain: Fleetms.Service,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      end

    vehicles =
      Fleetms.Vehicles.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    {:ok,
     socket
     |> assign(:form, form |> to_form())
     |> assign(:vehicles, vehicles)
     |> assign(:service_group, service_group)}
  end

  @impl true
  def handle_event("validate", %{"service_group" => service_group_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, service_group_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"service_group" => service_group_params}, socket) do
    save_service_group(socket, socket.assigns.action, service_group_params)
  end

  defp save_service_group(socket, :edit, service_group_params) do
    %{form: form, notify_parent: notify_parent} = socket.assigns

    case AshPhoenix.Form.submit(form, params: service_group_params) do
      {:ok, service_group} ->
        notify_parent({:saved, service_group}, notify_parent)

        {:noreply,
         socket
         |> put_flash(:info, "Service Group updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        # TODO: Show unique constraint errors, where a reminder for a vehicle exists and the
        # same vehicle is added to the service group
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_service_group(socket, :new, service_group_params) do
    %{form: form, notify_parent: notify_parent} = socket.assigns

    case AshPhoenix.Form.submit(form, params: service_group_params) do
      {:ok, service_group} ->
        notify_parent({:saved, service_group}, notify_parent)

        {:noreply,
         socket
         |> put_flash(:info, "Service Group created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(_msg, false), do: :ok
  defp notify_parent(msg, true), do: send(self(), {__MODULE__, msg})
end
