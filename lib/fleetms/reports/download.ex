defmodule Fleetms.Reports.Download do
  @root_dir to_string(:code.priv_dir(:fleetms))
  @destination_dir @root_dir <> "/reports/downloads"

  File.mkdir_p!(@destination_dir)

  def create_download_file("vehicles", tenant) do
    vehicles =
      Fleetms.VehicleManagement.Vehicle
      |> Ash.Query.load([:model, :vehicle_make])
      |> Ash.read!(tenant: tenant)

    headers =
      Enum.concat(
        Ash.Resource.Info.attributes(Fleetms.VehicleManagement.Vehicle),
        Ash.Resource.Info.aggregates(Fleetms.VehicleManagement.Vehicle)
      )
      |> Enum.map(fn %_struct{name: name} ->
        exclude = [:vehicle_group_id, :vehicle_model_id, :photo, :image_urk]
        if name not in exclude, do: name
      end)

    csv_iodata = into_csv(headers, vehicles)
    filename = "vehicles_#{get_timestamp()}.csv"
    File.write!("#{@destination_dir}/#{filename}", csv_iodata)

    filename
  end

  def into_csv(headers, list_of_records) do
    rows = [headers] ++ Enum.map(list_of_records, &row(&1, headers))

    csv_iodata =
      rows
      |> NimbleCSV.Spreadsheet.dump_to_iodata()
      |> IO.iodata_to_binary()

    csv_iodata
  end

  def row(%_struct{} = record, fields \\ []) do
    Enum.reduce(fields, [], fn field, acc ->
      List.insert_at(acc, -1, Map.get(record, field))
    end)
  end

  def get_timestamp do
    DateTime.utc_now()
    |> to_string()
    |> String.replace(" ", "_")
  end
end
