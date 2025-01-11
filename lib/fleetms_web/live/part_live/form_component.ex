defmodule FleetmsWeb.PartLive.FormComponent do
  use FleetmsWeb, :live_component

  @photos_upload_ref :part_photos
  @default_max_upload_entries 10

  @impl true
  def update(%{part: part} = assigns, socket) do
    socket = assign(socket, assigns)
    %{tenant: tenant, current_user: actor} = socket.assigns

    part_manufacturers =
      Fleetms.Inventory.PartManufacturer.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    part_categories =
      Fleetms.Inventory.PartCategory.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    part_unit_measurements =
      Fleetms.Inventory.PartUnitMeasurement.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    inventory_locations =
      Fleetms.Inventory.InventoryLocation.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    max_upload_entries = get_max_upload_entries(part)
    # TODO: Add uploads for Part photos and documents
    {:ok,
     socket
     |> assign_form(part)
     |> assign(:part_manufacturers, part_manufacturers)
     |> assign(:part_categories, part_categories)
     |> assign(:part_unit_measurements, part_unit_measurements)
     |> assign(:inventory_locations, inventory_locations)
     |> assign(:max_upload_entries, max_upload_entries)
     |> assign(:disallow_uploads, max_upload_entries == 0)
     |> assign(:upload_disallow_msg, nil)
     |> assign_upload_config()}
  end

  @impl true
  def handle_event("validate", %{"part" => part_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, part_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"part" => part_params}, socket) do
    save_part(socket, socket.assigns.action, part_params)
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, @photos_upload_ref, ref)}
  end

  @impl true
  def handle_event("add_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.add_form(socket.assigns.form, path)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, :form, form)}
  end

  defp save_part(socket, :edit, part_params) do
    {photos_to_delete_ids, part_params} =
      Map.pop(part_params, "photos_to_delete_ids", [])

    case AshPhoenix.Form.submit(socket.assigns.form, params: part_params) do
      {:ok, part} ->
        notify_parent({:saved, part})
        save_uploads(socket, part, photos_to_delete_ids)

        {:noreply,
         socket
         |> put_toast(:info, "Part updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_part(socket, :new, part_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: part_params) do
      {:ok, part} ->
        notify_parent({:saved, part})
        save_uploads(socket, part)

        {:noreply,
         socket
         |> put_toast(:info, "Part created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_uploads(socket, part, photos_to_delete_ids \\ [])

  defp save_uploads(socket, part, photos_to_delete_ids) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    definition_module = Fleetms.PartPhoto
    # default to empty list since vehicle.photos can be nil
    current_part_photos = get_current_part_photos(part)

    photos_to_keep_params =
      Stream.filter(current_part_photos, &(&1.id not in photos_to_delete_ids))
      |> Enum.map(&%{id: &1.id})

    # Check if uploads have been disallowed, so as to not run consume_uploaded_entry/3 which would fail if there is no upload config in the socket
    if socket.assigns.disallow_uploads do
      # TODO: Fix this duplication logic of updating vehcile photos, see line 207 and 216 as well
      Ash.Changeset.for_update(part, :maybe_delete_existing_photos, %{
        photo: get_photo_value(part, [], photos_to_keep_params),
        current_photos: photos_to_keep_params
      })
      |> Ash.update!(tenant: tenant, actor: actor)
    else
      case FleetmsWeb.UploadHandler.save(
             socket,
             @photos_upload_ref,
             definition_module,
             part
           ) do
        [] ->
          Ash.Changeset.for_update(part, :maybe_delete_existing_photos, %{
            photo: get_photo_value(part, [], photos_to_keep_params),
            current_photos: photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)

        filenames ->
          uploaded_photos_params = Enum.map(filenames, &%{filename: &1})

          Ash.Changeset.for_update(part, :save_part_photos, %{
            photo: get_photo_value(part, uploaded_photos_params, photos_to_keep_params),
            part_photos: uploaded_photos_params ++ photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)
      end
    end
  end

  # TODO: Impelement this function such that events are only sent
  # if the form component is on a listing page instead of a detail page
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp get_photo_value(
         %Fleetms.Inventory.Part{photo: photo_filename},
         uploaded_photos_params,
         photos_to_keep_params
       ) do
    cond do
      is_nil(photo_filename) and uploaded_photos_params == [] ->
        nil

      uploaded_photos_params == [] and photos_to_keep_params == [] ->
        nil

      is_nil(photo_filename) and uploaded_photos_params != [] ->
        hd(uploaded_photos_params)
        |> Map.get(:filename)

      true ->
        photo_filename
    end
  end

  defp get_max_upload_entries(nil), do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.Inventory.Part{part_photos: nil}),
    do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.Inventory.Part{part_photos: photos}) do
    total = Enum.count(photos)
    @default_max_upload_entries - total
  end

  defp assign_upload_config(socket) do
    max_upload_entries = socket.assigns.max_upload_entries

    upload_disallow_msg =
      "Max number of photos is reached, select photos to delete, save and upload new photos."

    if max_upload_entries == 0 do
      assign(socket, :upload_disallow_msg, upload_disallow_msg)
    else
      allow_upload(socket, @photos_upload_ref,
        accept: ~w(.jpg .jpeg .png),
        max_entries: max_upload_entries,
        max_file_size: 4096_000
      )
    end
  end

  defp get_current_part_photos(%Fleetms.Inventory.Part{part_photos: photos})
       when is_list(photos),
       do: photos

  defp get_current_part_photos(%Fleetms.Inventory.Part{part_photos: _photos}),
    do: []

  defp assign_form(socket, part) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    part_inventory_locations_form = [
      type: :list,
      resource: Fleetms.Inventory.PartInventoryLocation,
      create_action: :create,
      update_action: :update
    ]

    form =
      if part do
        part
        |> AshPhoenix.Form.for_action(:update,
          as: "part",
          domain: Fleetms.Inventory,
          actor: actor,
          tenant: tenant,
          forms: [
            part_inventory_locations:
              part_inventory_locations_form ++ [data: part.part_inventory_locations]
          ]
        )
      else
        Fleetms.Inventory.Part
        |> AshPhoenix.Form.for_create(:create,
          as: "part",
          domain: Fleetms.Inventory,
          actor: actor,
          tenant: tenant,
          forms: [
            part_inventory_locations: part_inventory_locations_form
          ]
        )
      end

    assign(socket, :form, form |> to_form())
  end
end
