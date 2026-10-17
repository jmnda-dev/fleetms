defmodule Fleetms.Repo.Migrations.AddObanJobs do
  @moduledoc """
  Creates Oban's tables in the public schema. Background jobs (e.g. the daily
  renewal digest) are global, not per-tenant; each job carries the tenant it acts
  on.
  """
  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 14)

  def down, do: Oban.Migration.down(version: 1)
end
