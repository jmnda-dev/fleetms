defmodule Fleetms.Maintenance.WorkOrderPhoto.Changes.ProcessUpload do
  @moduledoc """
  Turns the `:source_path` argument (an uploaded temp file) into a stored display
  image + thumbnail and sets their storage keys on the changeset. Runs before the
  insert; a processing/storage failure adds an error and the row is never created.
  Mirrors `Fleetms.VehicleIssues.IssuePhoto.Changes.ProcessUpload`.
  """
  use Ash.Resource.Change

  alias Fleetms.{Images, Storage}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &process/1)
  end

  defp process(changeset) do
    source = Ash.Changeset.get_argument(changeset, :source_path)
    work_order_id = Ash.Changeset.get_attribute(changeset, :work_order_id)
    base = "work_orders/#{work_order_id}/photos/#{Ecto.UUID.generate()}"
    image_key = base <> ".jpg"
    thumbnail_key = base <> "_thumb.jpg"
    display_tmp = tmp_path()
    thumb_tmp = tmp_path()

    try do
      with {:ok, _} <- Images.display(source, display_tmp),
           {:ok, _} <- Images.thumbnail(source, thumb_tmp),
           {:ok, _} <- Storage.put(image_key, display_tmp),
           {:ok, _} <- Storage.put(thumbnail_key, thumb_tmp) do
        changeset
        |> Ash.Changeset.force_change_attribute(:image_key, image_key)
        |> Ash.Changeset.force_change_attribute(:thumbnail_key, thumbnail_key)
      else
        _ ->
          Ash.Changeset.add_error(changeset,
            field: :source_path,
            message: "could not be processed as an image"
          )
      end
    after
      File.rm(display_tmp)
      File.rm(thumb_tmp)
    end
  end

  defp tmp_path, do: Path.join(System.tmp_dir!(), "fleetms-upload-#{Ecto.UUID.generate()}.jpg")
end
