defmodule Mix.Tasks.Fleetms.SyncPermissions do
  use Mix.Task

  @shortdoc "Sync permission declarations from code to the database"

  @moduledoc """
  Runs the permission sync process manually.

      mix fleetms.sync_permissions

  Useful after adding new permissions to verify the sync will succeed without
  restarting the server.
  """

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    Fleetms.Permissions.Sync.sync!()
    Mix.shell().info("✓ Permissions synced successfully.")
  end
end
