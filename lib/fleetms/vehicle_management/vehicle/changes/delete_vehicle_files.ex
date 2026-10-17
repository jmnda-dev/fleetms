defmodule Fleetms.VehicleManagement.Vehicle.Changes.DeleteVehicleFiles do
  @moduledoc """
  Deletes the storage objects for a vehicle's photos and documents when the
  vehicle itself is destroyed.

  The child rows are removed by the database FK cascade, which bypasses the
  per-row destroy hooks, so this collects every file key *before* the delete and
  removes the bytes *after* it succeeds. Best-effort and logged on failure — a
  storage hiccup must never block deleting the vehicle.
  """
  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(&collect_keys/1)
    |> Ash.Changeset.after_action(fn changeset, result ->
      changeset.context
      |> Map.get(:vehicle_file_keys, [])
      |> Enum.each(&delete/1)

      {:ok, result}
    end)
  end

  defp collect_keys(changeset) do
    vehicle =
      Ash.load!(changeset.data, [:photos, :documents],
        tenant: changeset.tenant,
        authorize?: false
      )

    photo_keys = Enum.flat_map(vehicle.photos, &[&1.image_key, &1.thumbnail_key])
    document_keys = Enum.map(vehicle.documents, & &1.storage_key)

    keys = Enum.reject(photo_keys ++ document_keys, &(is_nil(&1) or &1 == ""))
    Ash.Changeset.set_context(changeset, %{vehicle_file_keys: keys})
  end

  defp delete(key) do
    case Fleetms.Storage.delete(key) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to delete storage object #{key}: #{inspect(reason)}")
    end
  end
end
