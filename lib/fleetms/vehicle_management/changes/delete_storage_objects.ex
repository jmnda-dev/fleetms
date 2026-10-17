defmodule Fleetms.VehicleManagement.Changes.DeleteStorageObjects do
  @moduledoc """
  After a record is destroyed, delete the storage objects whose keys live in the
  given attributes. Use on resources that own uploaded files (photos, documents)
  so removing the row also removes the bytes.

      change {Fleetms.VehicleManagement.Changes.DeleteStorageObjects,
              keys: [:image_key, :thumbnail_key]}

  Storage deletes run in an `after_action` hook (the row is gone by then) and are
  best-effort: a missing object is already success, and a backend error is logged
  rather than failing the transaction, so a storage hiccup never blocks a delete.
  """
  use Ash.Resource.Change

  require Logger

  @impl true
  def init(opts) do
    case opts[:keys] do
      keys when is_list(keys) and keys != [] -> {:ok, opts}
      _ -> {:error, "keys must be a non-empty list of attribute names"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      opts[:keys]
      |> Enum.map(&Map.get(result, &1))
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.each(&delete/1)

      {:ok, result}
    end)
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
