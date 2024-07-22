defmodule FleetmsWeb.ReportLive.Summary do
  use FleetmsWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket, :active_link, :reports)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    tenant = socket.assigns.tenant
    summary_stats = Fleetms.Reports.Summary.get_summary_stats(tenant)

    socket = assign(socket, :summary_stats, summary_stats)

    {:noreply, socket}
  end
end
