defmodule FleetmsWeb.ReportLive.Download do
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket, :active_link, :reports)

    {:ok, socket}
  end

  @impl true
  def handle_event("download", %{"download_for" => "vehicles"}, socket) do
    filename = Fleetms.Reports.Download.create_download_file("vehicles", socket.assigns.tenant)
    download_link = ~p"/reports/downloads/#{filename}"

    {:noreply, push_event(socket, "create_download_link", %{download_link: download_link})}
  end
end
