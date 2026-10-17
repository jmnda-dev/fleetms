defmodule Fleetms.Permissions.Sync do
  @moduledoc """
  Syncs permissions declared in code with the `public.permissions` table.

    * New permissions are inserted.
    * Changed labels/groups are updated.
    * Permissions removed from code are soft-deleted (`active: false`).

  Idempotent and safe to run on every boot.
  """
  require Logger
  require Ash.Query

  alias Fleetms.Accounts.Permission

  @spec sync!() :: :ok
  def sync! do
    Logger.info("[Permissions.Sync] Starting permission sync...")

    # The manifest expands multi-action permissions; collapse to one row per
    # unique permission name for the `public.permissions` table.
    declared = Enum.uniq_by(Fleetms.Permissions.Manifest.all(), & &1.name)
    declared_names = MapSet.new(declared, & &1.name)

    case Ash.bulk_create(declared, Permission, :upsert,
           authorize?: false,
           return_errors?: true,
           stop_on_error?: true
         ) do
      %Ash.BulkResult{status: :success, records: records} ->
        Logger.info("[Permissions.Sync] Upserted #{length(records || [])} permissions.")

      %Ash.BulkResult{status: :error, errors: errors} ->
        Logger.error("[Permissions.Sync] Upsert errors: #{inspect(errors)}")
        raise "Permission sync failed during upsert."
    end

    deactivate_stale(declared_names)

    Fleetms.Permissions.Cache.reload!()

    Logger.info("[Permissions.Sync] Done. #{MapSet.size(declared_names)} active permissions.")
    :ok
  end

  defp deactivate_stale(declared_names) do
    existing_active =
      Permission
      |> Ash.Query.filter(active == true)
      |> Ash.read!(authorize?: false)

    stale = Enum.reject(existing_active, fn p -> MapSet.member?(declared_names, p.name) end)

    if stale != [] do
      stale_names = Enum.map_join(stale, ", ", & &1.name)
      Logger.warning("[Permissions.Sync] Deactivating #{length(stale)} removed: #{stale_names}")

      case Ash.bulk_update(stale, :deactivate, %{}, authorize?: false, return_errors?: true) do
        %Ash.BulkResult{status: :success} ->
          :ok

        %Ash.BulkResult{errors: errors} ->
          Logger.error("[Permissions.Sync] Deactivation errors: #{inspect(errors)}")
      end
    end

    :ok
  end
end
