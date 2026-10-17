defmodule Fleetms.VehicleManagement.VehicleDocument.Changes.StoreUpload do
  @moduledoc """
  Stores the `:source_path` argument (an uploaded temp file) via `Fleetms.Storage`
  and sets the resulting `storage_key` on the changeset.

  The domain seam between the storage infrastructure and creating a
  `VehicleDocument`. Runs before the insert so the required `storage_key` is set;
  a storage failure adds an error and the row is never created.
  """
  use Ash.Resource.Change

  alias Fleetms.Storage

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &store/1)
  end

  defp store(changeset) do
    source = Ash.Changeset.get_argument(changeset, :source_path)
    vehicle_id = Ash.Changeset.get_attribute(changeset, :vehicle_id)
    filename = Ash.Changeset.get_attribute(changeset, :filename) || "file"
    key = "vehicles/#{vehicle_id}/documents/#{Ecto.UUID.generate()}#{Path.extname(filename)}"

    case Storage.put(key, source) do
      {:ok, _} ->
        Ash.Changeset.force_change_attribute(changeset, :storage_key, key)

      {:error, _} ->
        Ash.Changeset.add_error(changeset, field: :source_path, message: "could not be stored")
    end
  end
end
