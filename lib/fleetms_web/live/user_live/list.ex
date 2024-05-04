defmodule FleetmsWeb.UserLive.List do
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts.User

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    users = Ash.read!(User)

    socket = stream(socket, :users, users)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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