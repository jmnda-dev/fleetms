defmodule FleetmsWeb.DownloadController do
  use FleetmsWeb, :controller

  def report_download(conn, %{"filename" => filename}) do
    file_path = "#{:code.priv_dir(:fleetms)}/reports/downloads/#{filename}"
    send_download(conn, {:file, file_path})
  end
end
