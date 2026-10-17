defmodule FleetmsWeb.ApiUploadController do
  @moduledoc """
  A dedicated HTTP multipart/form-data endpoint for mobile photo/signature uploads.
  Accepts a file, processes it (resizes and generates a thumbnail), and stores
  both using the standard `Fleetms.Images` and `Fleetms.Storage` pipelines.
  Returns `{image_key, thumbnail_key}` to be included in JSON APIs (like submitting an inspection).
  """
  use FleetmsWeb, :controller

  def create(conn, %{"file" => %Plug.Upload{path: path}}) do
    case store_photo(path) do
      %{"image_key" => image_key, "thumbnail_key" => thumbnail_key} ->
        conn
        |> put_status(:created)
        |> json(%{image_key: image_key, thumbnail_key: thumbnail_key})

      nil ->
        error(conn, 422, "Could not process or store the uploaded image.")
    end
  end

  def create(conn, _params) do
    error(conn, 400, "Missing 'file' in multipart/form-data request.")
  end

  def delete(conn, %{"image_key" => image_key, "thumbnail_key" => thumbnail_key}) do
    Fleetms.Storage.delete(image_key)
    Fleetms.Storage.delete(thumbnail_key)
    send_resp(conn, :no_content, "")
  end

  def delete(conn, _params) do
    error(conn, 400, "Missing 'image_key' or 'thumbnail_key'.")
  end

  defp store_photo(source) do
    base = "inspections/answers/#{Ecto.UUID.generate()}"
    image_key = base <> ".jpg"
    thumbnail_key = base <> "_thumb.jpg"
    display_tmp = tmp_path()
    thumb_tmp = tmp_path()

    try do
      with {:ok, _} <- Fleetms.Images.display(source, display_tmp),
           {:ok, _} <- Fleetms.Images.thumbnail(source, thumb_tmp),
           {:ok, _} <- Fleetms.Storage.put(image_key, display_tmp),
           {:ok, _} <- Fleetms.Storage.put(thumbnail_key, thumb_tmp) do
        %{"image_key" => image_key, "thumbnail_key" => thumbnail_key}
      else
        _ -> nil
      end
    after
      File.rm(display_tmp)
      File.rm(thumb_tmp)
    end
  end

  defp tmp_path, do: Path.join(System.tmp_dir!(), "fleetms-upload-#{Ecto.UUID.generate()}.jpg")

  defp error(conn, status, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: [%{status: to_string(status), detail: detail}]})
  end
end
