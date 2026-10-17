defmodule FleetmsWeb.VehicleController do
  @moduledoc """
  Controller-served vehicle downloads. Currently just the CSV template for the bulk
  importer (see `Fleetms.VehicleManagement.VehicleImport` and `VehicleLive.Import`).
  """
  use FleetmsWeb, :controller

  alias Fleetms.VehicleManagement.VehicleImport

  def import_template(conn, _params) do
    body = VehicleImport.Parser.dump_to_iodata(VehicleImport.template_rows())

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header(
      "content-disposition",
      ~s(attachment; filename="vehicle-import-template.csv")
    )
    |> send_resp(200, body)
  end
end
