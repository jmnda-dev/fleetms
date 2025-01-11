defmodule FleetmsWeb.DownloadController do
  use FleetmsWeb, :controller

  def report_download(conn, %{"filename" => filename}) do
    if conn.assigns[:current_user] do
      file_path = "#{:code.priv_dir(:fleetms)}/reports/downloads/#{filename}"
      send_download(conn, {:file, file_path})
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end
end
