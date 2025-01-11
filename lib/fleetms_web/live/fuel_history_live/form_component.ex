defmodule FleetmsWeb.FuelHistoryLive.FormComponent do
  use FleetmsWeb, :live_component
  alias Fleetms.Accounts

  @photos_upload_ref :fuel_history_photos
  @default_max_upload_entries 10

  @impl true
  def update(%{fuel_history: fuel_history} = assigns, socket) do
    socket = assign(socket, assigns)

    max_upload_entries = get_max_upload_entries(fuel_history)
    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      if fuel_history do
        fuel_history
        |> AshPhoenix.Form.for_update(:update,
          as: "fuel_history",
          domain: Fleetms.FuelManagement,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      else
        Fleetms.FuelManagement.FuelHistory
        |> AshPhoenix.Form.for_create(:create,
          as: "fuel_history",
          domain: Fleetms.FuelManagement,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      end

    vehicles =
      Fleetms.VehicleManagement.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    users =
      Accounts.get_all_users!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.user_profile.full_name, &1.id})

    socket =
      socket
      |> assign(:form, to_form(form))
      |> assign(:vehicles, vehicles)
      |> assign(:users, users)
      |> assign(:max_upload_entries, max_upload_entries)
      |> assign(:disallow_uploads, max_upload_entries == 0)
      |> assign(:upload_disallow_msg, nil)
      |> assign_upload_config()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"fuel_history" => fuel_history_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, fuel_history_params)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"fuel_history" => fuel_history_params}, socket) do
    save_fuel_history(socket, socket.assigns.action, fuel_history_params)
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :fuel_history_photos, ref)}
  end

  defp save_fuel_history(socket, :edit, fuel_history_params) do
    {photos_to_delete_ids, fuel_history_params} =
      Map.pop(fuel_history_params, "photos_to_delete_ids", [])

    case AshPhoenix.Form.submit(socket.assigns.form, params: fuel_history_params) do
      {:ok, fuel_history} ->
        save_uploads(socket, fuel_history, photos_to_delete_ids)
        notify_parent({:saved, fuel_history})

        {:noreply,
         socket
         |> put_toast(:info, "Fuel History updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_fuel_history(socket, :new, fuel_history_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: fuel_history_params) do
      {:ok, fuel_history} ->
        save_uploads(socket, fuel_history)

        notify_parent({:saved, fuel_history})

        {:noreply,
         socket
         |> put_toast(:info, "Fuel History created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp save_uploads(socket, fuel_history, photos_to_delete_ids \\ [])

  defp save_uploads(socket, fuel_history, photos_to_delete_ids) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    definition_module = Fleetms.FuelHistoryPhoto
    # default to empty list since vehicle.photos can be nil
    current_fuel_history_photos = get_current_fuel_history_photos(fuel_history)

    photos_to_keep_params =
      Stream.filter(current_fuel_history_photos, &(&1.id not in photos_to_delete_ids))
      |> Enum.map(&%{id: &1.id})

    # Check if uploads have been disallowed, so as to not run consume_uploaded_entry/3 which would fail if there is no upload config in the socket
    if socket.assigns.disallow_uploads do
      # TODO: Fix this duplication logic of updating vehcile photos, see line 207 and 216 as well
      Ash.Changeset.for_update(fuel_history, :maybe_delete_existing_photos, %{
        current_photos: photos_to_keep_params
      })
      |> Ash.update!(tenant: tenant, actor: actor)
    else
      case FleetmsWeb.UploadHandler.save(
             socket,
             @photos_upload_ref,
             definition_module,
             fuel_history
           ) do
        [] ->
          Ash.Changeset.for_update(fuel_history, :maybe_delete_existing_photos, %{
            current_photos: photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)

        filenames ->
          uploaded_photos_params = Enum.map(filenames, &%{filename: &1})

          Ash.Changeset.for_update(fuel_history, :save_fuel_history_photos, %{
            fuel_history_photos: uploaded_photos_params ++ photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)
      end
    end
  end

  defp get_max_upload_entries(nil), do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.FuelManagement.FuelHistory{fuel_history_photos: nil}),
    do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.FuelManagement.FuelHistory{fuel_history_photos: photos}) do
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

  defp get_current_fuel_history_photos(%Fleetms.FuelManagement.FuelHistory{
         fuel_history_photos: photos
       })
       when is_list(photos),
       do: photos

  defp get_current_fuel_history_photos(%Fleetms.FuelManagement.FuelHistory{
         fuel_history_photos: _photos
       }),
       do: []
end
