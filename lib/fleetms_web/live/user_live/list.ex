defmodule FleetmsWeb.UserLive.List do
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts.User

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    users = Ash.read!(User)

    {:noreply, stream(socket, :users, users)}
  end
end
