defmodule FleetmsWeb.UserLive.Profile do
  use FleetmsWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      update(socket, :current_user, fn user -> Ash.load!(user, :organization) end)
      |> assign(:active_link, nil)
    {:ok, socket}
  end
end
