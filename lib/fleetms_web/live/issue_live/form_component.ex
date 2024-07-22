defmodule FleetmsWeb.IssueLive.FormComponent do
  use FleetmsWeb, :live_component

  alias Fleetms.Accounts

  @photos_upload_ref :issue_photos
  @default_max_upload_entries 10

  @impl true
  def update(%{issue: issue} = assigns, socket) do
    max_upload_entries = get_max_upload_entries(issue)

    socket =
      assign(socket, assigns)
      |> form_assigns()
      |> assign_form()
      |> assign(:max_upload_entries, max_upload_entries)
      |> assign(:disallow_uploads, max_upload_entries == 0)
      |> assign(:upload_disallow_msg, nil)
      |> assign_upload_config()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"issue" => issue_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, issue_params)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"issue" => issue_params}, socket) do
    save_issue(socket, socket.assigns.action, issue_params)
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :issue_photos, ref)}
  end

  defp save_issue(socket, :edit, issue_params) do
    {photos_to_delete_ids, issue_params} = Map.pop(issue_params, "photos_to_delete_ids", [])

    case AshPhoenix.Form.submit(socket.assigns.form, params: issue_params) do
      {:ok, issue} ->
        save_uploads(socket, issue, photos_to_delete_ids)
        notify_parent({:saved, issue})

        {:noreply,
         socket
         |> put_flash(:info, "Issue updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_issue(socket, :new, issue_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: issue_params) do
      {:ok, issue} ->
        save_uploads(socket, issue)

        notify_parent({:saved, issue})

        {:noreply,
         socket
         |> put_flash(:info, "Issue created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_issue(socket, :resolve_issue_with_comment, issue_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: issue_params) do
      {:ok, issue} ->
        notify_parent({:saved, issue})

        {:noreply,
         socket
         |> put_flash(:success, "Issue ##{issue.issue_number} is resolved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_issue(socket, :close_issue, issue_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: issue_params) do
      {:ok, issue} ->
        notify_parent({:saved, issue})

        {:noreply,
         socket
         |> put_flash(:warning, "Issue ##{issue.issue_number} is Closed")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_issue(socket, :reopen_issue, issue_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: issue_params) do
      {:ok, issue} ->
        notify_parent({:saved, issue})

        {:noreply,
         socket
         |> put_flash(:info, "Issue ##{issue.issue_number} is Opened")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp save_uploads(socket, issue, photos_to_delete_ids \\ [])

  defp save_uploads(socket, issue, photos_to_delete_ids) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    definition_module = Fleetms.IssuePhoto
    # default to empty list since vehicle.photos can be nil
    current_issue_photos = get_current_issue_photos(issue)

    photos_to_keep_params =
      Stream.filter(current_issue_photos, &(&1.id not in photos_to_delete_ids))
      |> Enum.map(&%{id: &1.id})

    # Check if uploads have been disallowed, so as to not run consume_uploaded_entry/3 which would fail if there is no upload config in the socket
    if socket.assigns.disallow_uploads do
      # TODO: Fix this duplication logic of updating vehcile photos, see line 207 and 216 as well
      Ash.Changeset.for_update(issue, :maybe_delete_existing_photos, %{
        current_photos: photos_to_keep_params
      })
      |> Ash.update!(tenant: tenant, actor: actor)
    else
      case FleetmsWeb.UploadHandler.save(socket, @photos_upload_ref, definition_module, issue) do
        [] ->
          Ash.Changeset.for_update(issue, :maybe_delete_existing_photos, %{
            current_photos: photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)

        filenames ->
          uploaded_photos_params = Enum.map(filenames, &%{filename: &1})

          Ash.Changeset.for_update(issue, :save_issue_photos, %{
            issue_photos: uploaded_photos_params ++ photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)
      end
    end
  end

  defp form_assigns(socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    if socket.assigns.action in [:new, :edit] do
      vehicles = Fleetms.Vehicles.Vehicle.get_all!(tenant: tenant, actor: actor)

      users =
        Accounts.get_all_users!(tenant: tenant, actor: actor)
        |> Enum.map(&{&1.user_profile.full_name, &1.id})

      socket
      |> assign(:vehicles, vehicles)
      |> assign(:users, users)
    else
      socket
    end
  end

  defp assign_form(socket) do
    %{action: action, issue: issue, tenant: tenant, current_user: actor} = socket.assigns

    form =
      cond do
        action == :edit ->
          issue
          |> AshPhoenix.Form.for_action(:update,
            as: "issue",
            domain: Fleetms.Issues,
            actor: actor,
            tenant: tenant,
            forms: [auto?: true]
          )

        action == :close_issue ->
          issue
          |> AshPhoenix.Form.for_action(:close_issue,
            as: "issue",
            domain: Fleetms.Issues,
            actor: actor,
            tenant: tenant,
            forms: [auto?: true]
          )

        action == :resolve_issue_with_comment ->
          issue
          |> AshPhoenix.Form.for_action(:resolve_issue_with_comment,
            as: "issue",
            domain: Fleetms.Issues,
            actor: actor,
            tenant: tenant,
            forms: [auto?: true]
          )

        action == :reopen_issue ->
          issue
          |> AshPhoenix.Form.for_action(:reopen_issue,
            as: "issue",
            domain: Fleetms.Issues,
            actor: actor,
            tenant: tenant,
            forms: [auto?: true]
          )

        true ->
          Fleetms.Issues.Issue
          |> AshPhoenix.Form.for_create(:create,
            as: "issue",
            domain: Fleetms.Issues,
            actor: actor,
            tenant: tenant,
            forms: [auto?: true]
          )
      end

    assign(socket, :form, to_form(form))
  end

  defp get_max_upload_entries(nil), do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.Issues.Issue{issue_photos: nil}),
    do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.Issues.Issue{issue_photos: photos}) do
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

  defp get_current_issue_photos(%Fleetms.Issues.Issue{issue_photos: photos}) when is_list(photos),
    do: photos

  defp get_current_issue_photos(%Fleetms.Issues.Issue{issue_photos: _photos}), do: []
end
