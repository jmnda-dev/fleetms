defmodule FleetmsWeb.UserLive.List do
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts
  alias Fleetms.Accounts.User

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    users = Ash.read!(User)

    socket = stream(socket, :users, users)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_info({FleetmsWeb.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    user = Accounts.get_user_by_id!(id)

    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, user)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, nil)
  end

  defp apply_action(socket, :listing, _params) do
    socket
    |> assign(:page_title, "User Listing")
    |> assign(:user, nil)
  end
end
