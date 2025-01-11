defmodule FleetmsWeb.UserLive.Settings do
  use FleetmsWeb, :live_view
  alias Fleetms.Accounts

  @photo_upload_ref :profile_photo

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    profile_update_form =
      socket.assigns.current_user.user_profile
      |> AshPhoenix.Form.for_update(:update, domain: Accounts, as: "user_profile")
      |> to_form()

    change_password_form =
      socket.assigns.current_user
      |> AshPhoenix.Form.for_update(:change_password, domain: Accounts, as: "change_password")
      |> to_form()

    socket =
      assign(socket, :profile_form, profile_update_form)
      |> assign(:change_password_form, change_password_form)
      |> allow_upload(@photo_upload_ref,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 1,
        max_file_size: 4096_000
      )
      |> assign(:active_link, nil)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_profile_form", %{"user_profile" => user_profile_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.profile_form, user_profile_params)

    {:noreply, assign(socket, :profile_form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "validate_change_password_form",
        %{"change_password" => change_password_params},
        socket
      ) do
    form = AshPhoenix.Form.validate(socket.assigns.change_password_form, change_password_params)

    {:noreply, assign(socket, :change_password_form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event("save_profile", %{"user_profile" => user_profile_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.profile_form, params: user_profile_params) do
      {:ok, user_profile} ->
        maybe_handle_upload(socket, user_profile)

        {:noreply,
         socket
         |> put_toast(:info, "Profile information was updated successfully")
         |> push_navigate(to: ~p"/settings")}

      {:error, form} ->
        {:noreply, assign(socket, :profile_form, form)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_password", %{"change_password" => change_password_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.change_password_form,
           params: change_password_params
         ) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> put_toast(:info, "Password was updated successfully")
         |> push_navigate(to: ~p"/settings")}

      {:error, form} ->
        {:noreply, assign(socket, :change_password_form, form)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, @photo_upload_ref, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_profile_photo", _params, socket) do
    Fleetms.Accounts.remove_profile_photo!(socket.assigns.current_user.user_profile)

    {:noreply,
     socket
     |> put_toast(:info, "Your Profile was removed")
     |> push_navigate(to: ~p"/settings")}
  end

  defp maybe_handle_upload(socket, user_profile_resource) do
    definition_module = Fleetms.UserProfilePhoto

    case FleetmsWeb.UploadHandler.save(
           socket,
           @photo_upload_ref,
           definition_module,
           user_profile_resource
         ) do
      [] ->
        :ok

      [filename | _] ->
        Fleetms.Accounts.update_profile_photo!(user_profile_resource, %{profile_photo: filename})
    end
  end
end
