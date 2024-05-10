defmodule FleetmsWeb.UserLive.Settings do
  use FleetmsWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    profile_update_form =
      socket.assigns.current_user.user_profile
      |> AshPhoenix.Form.for_update(:update, as: "user_profile")
      |> to_form()

    socket = assign(socket, :profile_form, profile_update_form)
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
  def handle_event("save_profile", %{"user_profile" => user_profile_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.profile_form, params: user_profile_params) do
      {:ok, _user_profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile information was updated successfully")
         |> push_redirect(to: ~p"/settings")}

      {:error, form} ->
        {:noreply, assign(socket, :profile_form, form)}
    end
  end
end
