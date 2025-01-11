defmodule FleetmsWeb.InventoryLocationLive.FormComponent do
  use FleetmsWeb, :live_component

  @impl true
  def update(%{inventory_location: inventory_location} = assigns, socket) do
    socket =
      assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      if inventory_location do
        inventory_location
        |> AshPhoenix.Form.for_action(:update,
          as: "inventory_location",
          domain: Fleetms.Inventory,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      else
        Fleetms.Inventory.InventoryLocation
        |> AshPhoenix.Form.for_create(:create,
          as: "inventory_location",
          domain: Fleetms.Inventory,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      end

    {:ok,
     socket
     |> assign(:form, form |> to_form())}
  end

  @impl true
  def handle_event("validate", %{"inventory_location" => inventory_location_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, inventory_location_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"inventory_location" => inventory_location_params}, socket) do
    save_inventory_location(socket, socket.assigns.action, inventory_location_params)
  end

  defp save_inventory_location(socket, :edit, inventory_location_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: inventory_location_params) do
      {:ok, inventory_location} ->
        notify_parent({:saved, inventory_location})

        {:noreply,
         socket
         |> put_toast(:info, "Inventory Location updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_inventory_location(socket, :new, inventory_location_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: inventory_location_params) do
      {:ok, inventory_location} ->
        notify_parent({:saved, inventory_location})

        {:noreply,
         socket
         |> put_toast(:info, "Inventory Location created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  # TODO: Impelement this function such that events are only sent
  # if the form component is on a listing page instead of a detail page
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
