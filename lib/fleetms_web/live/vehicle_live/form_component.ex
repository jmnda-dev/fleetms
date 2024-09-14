defmodule FleetmsWeb.VehicleLive.FormComponent do
  alias Fleetms.Vehicles.Vehicle
  use FleetmsWeb, :live_component

  @photos_upload_ref :vehicle_photos
  @documents_upload_ref :vehicle_documents
  @default_max_document_upload_entries 30

  @impl true
  def update(%{vehicle_models: vehicle_models} = _assigns, socket) do
    new_options =
      Enum.map(vehicle_models, &%{id: &1.name, text: &1.name})

    socket = assign(socket, :vehicle_models, vehicle_models)

    {:ok, push_event(socket, "set_new_options", %{targetEl: "other-input", data: new_options})}
  end

  @impl true
  def update(%{vehicle: vehicle} = assigns, socket) do
    socket = assign(socket, assigns)
    %{tenant: tenant, current_user: actor} = socket.assigns
    # TODO: Perhaps use an Ash Resource aggregate to determine the number of uploads to allow
    max_document_upload_entries = get_max_document_upload_entries(vehicle)

    vehicle_makes = Fleetms.Vehicles.VehicleMake.get_all!(tenant: tenant, actor: actor)

    socket =
      socket
      |> assign(:max_document_upload_entries, max_document_upload_entries)
      |> assign(:disallow_document_uploads, max_document_upload_entries == 0)
      |> assign_form()
      |> assign(:vehicle_makes, vehicle_makes)
      |> assign(:upload_photo_disallow_msg, nil)
      |> assign(:upload_document_disallow_msg, nil)
      |> assign_vehicle_models(vehicle)
      |> assign_photo_upload_config()
      |> assign_document_upload_config()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"vehicle" => vehicle_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, vehicle_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"vehicle" => vehicle_params}, socket) do
    save_vehicle(socket, socket.assigns.action, vehicle_params)
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :vehicle_photos, ref)}
  end

  @impl true
  def handle_event("remove_document", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :vehicle_documents, ref)}
  end

  defp save_vehicle(socket, :edit, vehicle_params) do
    {photos_to_delete_ids, vehicle_params} = Map.pop(vehicle_params, "photos_to_delete_ids", [])

    {documents_to_delete_ids, vehicle_params} =
      Map.pop(vehicle_params, "documents_to_delete_ids", [])

    case AshPhoenix.Form.submit(socket.assigns.form, params: vehicle_params) do
      {:ok, vehicle} ->
        save_uploads(socket, vehicle, photos_to_delete_ids)
        save_document_uploads(socket, vehicle, documents_to_delete_ids)
        notify_parent({:saved, vehicle})

        {:noreply,
         socket
         |> put_flash(:info, "Vehicle was updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_vehicle(socket, :add, vehicle_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: vehicle_params) do
      {:ok, vehicle} ->
        save_uploads(socket, vehicle)
        save_document_uploads(socket, vehicle)

        notify_parent({:saved, vehicle})

        {:noreply,
         socket
         |> put_flash(:info, "Vehicle was added successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_vehicle_models(socket, vehicle) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    case socket.assigns.action do
      :add ->
        assign(socket, :vehicle_models, [])

      :edit ->
        vehicle_models =
          Fleetms.Vehicles.VehicleModel.list_by_vehicle_make!(vehicle.vehicle_make,
            tenant: tenant,
            actor: actor
          )

        assign(socket, :vehicle_models, vehicle_models)
    end
  end

  defp assign_form(%{assigns: %{vehicle: vehicle}} = socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      if vehicle do
        AshPhoenix.Form.for_update(vehicle, :update,
          domain: Fleetms.Vehicles,
          as: "vehicle",
          actor: actor,
          tenant: tenant,
          forms: [
            vehicle_model: [
              type: :single,
              resource: Fleetms.Vehicles.VehicleModel,
              data: vehicle.vehicle_model,
              create_action: :create,
              update_action: :update,
              forms: [
                vehicle_make: [
                  type: :single,
                  resource: Fleetms.Vehicles.VehicleMake,
                  data: vehicle.vehicle_model.vehicle_make,
                  create_action: :create,
                  update_action: :update
                ]
              ]
            ],
            vehicle_engine_spec: [
              type: :single,
              resource: Fleetms.Vehicles.VehicleEngineSpec,
              data: vehicle.vehicle_engine_spec,
              create_action: :create,
              update_action: :update
            ],
            vehicle_drivetrain_spec: [
              type: :single,
              resource: Fleetms.Vehicles.VehicleDrivetrainSpec,
              data: vehicle.vehicle_drivetrain_spec,
              create_action: :create,
              update_action: :update
            ],
            vehicle_other_spec: [
              type: :single,
              resource: Fleetms.Vehicles.VehicleOtherSpec,
              data: vehicle.vehicle_other_spec,
              create_action: :create,
              update_action: :update
            ],
            vehicle_performance_spec: [
              type: :single,
              resource: Fleetms.Vehicles.VehiclePerformanceSpec,
              data: vehicle.vehicle_performance_spec,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
      else
        AshPhoenix.Form.for_create(Fleetms.Vehicles.Vehicle, :create,
          domain: Fleetms.Vehicles,
          as: "vehicle",
          actor: actor,
          tenant: tenant,
          forms: [
            vehicle_model: [
              type: :single,
              resource: Fleetms.Vehicles.VehicleModel,
              create_action: :create,
              update_action: :update,
              forms: [
                vehicle_make: [
                  type: :single,
                  resource: Fleetms.Vehicles.VehicleMake,
                  create_action: :create,
                  update_action: :update
                ]
              ]
            ]
          ]
        )
        |> AshPhoenix.Form.add_form("vehicle[vehicle_model]")
        |> AshPhoenix.Form.add_form("vehicle[vehicle_model][vehicle_make]")
      end

    assign(socket, form: to_form(form))
  end

  defp save_uploads(socket, vehicle, photos_to_delete_ids \\ [])

  defp save_uploads(socket, vehicle, photos_to_delete_ids) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    definition_module = Fleetms.VehiclePhoto
    # default to empty list since vehicle.photos can be nil
    current_vehicle_photos = get_current_vehicle_photos(vehicle)

    photos_to_keep_params =
      Stream.filter(current_vehicle_photos, &(&1.id not in photos_to_delete_ids))
      |> Enum.map(&%{id: &1.id})

    # Check if uploads have been disallowed, so as to not run consume_uploaded_entry/3 which would fail if there is no upload config in the socket
    if socket.assigns.photo_upload_disallowed? do
      # TODO: Fix this duplication logic of updating vehicle photos, see line 207 and 216 as well
      Ash.Changeset.for_update(vehicle, :maybe_delete_existing_photos, %{
        photo: get_photo_value(vehicle, [], photos_to_keep_params),
        current_photos: photos_to_keep_params
      })
      |> Ash.update!(tenant: tenant, actor: actor)
    else
      case FleetmsWeb.UploadHandler.save(socket, @photos_upload_ref, definition_module, vehicle) do
        [] ->
          Ash.Changeset.for_update(vehicle, :maybe_delete_existing_photos, %{
            photo: get_photo_value(vehicle, [], photos_to_keep_params),
            current_photos: photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)

        filenames ->
          uploaded_photos_params = Enum.map(filenames, &%{filename: &1})

          Ash.Changeset.for_update(vehicle, :save_vehicle_photos, %{
            photo: get_photo_value(vehicle, uploaded_photos_params, photos_to_keep_params),
            photos: uploaded_photos_params ++ photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)
      end
    end
  end

  defp save_document_uploads(socket, vehicle, documents_to_delete_ids \\ [])

  defp save_document_uploads(socket, vehicle, documents_to_delete_ids) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    definition_module = Fleetms.VehicleDocument

    current_vehicle_documents = get_current_vehicle_documents(vehicle)

    documents_to_keep_params =
      Stream.filter(current_vehicle_documents, &(&1.id not in documents_to_delete_ids))
      |> Enum.map(&%{id: &1.id})

    if socket.assigns.disallow_document_uploads do
      Ash.Changeset.for_update(vehicle, :maybe_delete_existing_documents, %{
        current_documents: documents_to_keep_params
      })
      |> Ash.update!(tenant: tenant, actor: actor)
    else
      case FleetmsWeb.UploadHandler.save(
             socket,
             @documents_upload_ref,
             definition_module,
             vehicle,
             return_file_type: true,
             return_original_filename: true
           ) do
        [] ->
          Ash.Changeset.for_update(vehicle, :maybe_delete_existing_documents, %{
            current_documents: documents_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)

        filenames ->
          uploaded_documents_params =
            Enum.map(filenames, fn {new_filename, original_filename, file_type} ->
              %{storage_filename: new_filename, filename: original_filename, file_type: file_type}
            end)

          Ash.Changeset.for_update(vehicle, :save_vehicle_documents, %{
            documents: uploaded_documents_params ++ documents_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)
      end
    end
  end

  defp get_photo_value(
         %Fleetms.Vehicles.Vehicle{photo: photo_filename},
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

  defp get_max_document_upload_entries(nil), do: @default_max_document_upload_entries

  defp get_max_document_upload_entries(%Fleetms.Vehicles.Vehicle{documents: nil}),
    do: @default_max_document_upload_entries

  defp get_max_document_upload_entries(%Fleetms.Vehicles.Vehicle{documents: documents}) do
    total = Enum.count(documents)
    @default_max_document_upload_entries - total
  end

  defp assign_photo_upload_config(socket) do
    num_of_max_uploads = Vehicle.get_max_photo_uploads()
    vehicle = socket.assigns.vehicle

    cond do
      is_nil(vehicle) ->
        allow_upload(socket, @photos_upload_ref,
          accept: ~w(.jpg .jpeg .png),
          max_entries: num_of_max_uploads,
          max_file_size: 4096_000
        )
        |> assign(:photo_upload_disallowed?, true)

      vehicle.num_of_photos == num_of_max_uploads ->
        assign(socket,
          photo_upload_disallowed?: true,
          photo_upload_disallow_msg:
            "Max number of photos is reached, select photos to delete, save and upload new photos."
        )

      vehicle.num_of_photos < num_of_max_uploads ->
        allow_upload(socket, @photos_upload_ref,
          accept: ~w(.jpg .jpeg .png),
          max_entries: num_of_max_uploads - vehicle.num_of_photos,
          max_file_size: 4096_000
        )
        |> assign(:photo_upload_disallowed?, false)
    end
  end

  defp assign_document_upload_config(socket) do
    max_document_upload_entries = socket.assigns.max_document_upload_entries

    upload_disallow_msg =
      "Max number of documents is reached, select documents to delete, save and upload new documents."

    if max_document_upload_entries == 0 do
      assign(socket, :upload_disallow_msg, upload_disallow_msg)
    else
      allow_upload(socket, @documents_upload_ref,
        accept: ~w(.pdf .docx .xlsx),
        max_entries: max_document_upload_entries,
        max_file_size: 8196_000
      )
    end
  end

  defp get_current_vehicle_photos(%Fleetms.Vehicles.Vehicle{photos: photos}) when is_list(photos),
    do: photos

  defp get_current_vehicle_photos(%Fleetms.Vehicles.Vehicle{photos: _photos}), do: []

  defp get_current_vehicle_documents(%Fleetms.Vehicles.Vehicle{documents: documents})
       when is_list(documents),
       do: documents

  defp get_current_vehicle_documents(%Fleetms.Vehicles.Vehicle{documents: _documents}), do: []
end
