defmodule FleetmsWeb.VehicleDocumentDownloadController do
  use FleetmsWeb, :controller
  alias Fleetms.VehicleManagement

  def download(conn, %{"id" => id}) do
    if conn.assigns[:current_user] do
      tenant = get_session(conn, :tenant)
      %{current_user: actor} = conn.assigns

      document =
        VehicleManagement.get_document_by_id!(id, tenant: tenant, actor: actor)
        |> Ash.load!(:vehicle)

      file_path =
        Path.join([
          "uploads",
          "vehicles",
          "documents",
          document.vehicle.id,
          document.storage_filename
        ])

      conn
      |> put_resp_content_type(MIME.from_path(document.storage_filename))
      |> put_resp_header("content-disposition", "attachment; filename=\"#{document.filename}\"")
      |> send_file(200, file_path)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end
end
