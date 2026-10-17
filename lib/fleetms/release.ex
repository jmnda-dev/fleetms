defmodule Fleetms.Release do
  @moduledoc """
  DB release tasks, run in production where Mix isn't available (e.g. Fly's
  `release_command`, or `bin/fleetms eval`).

  `migrate/0` brings the **public** schema up to date. It is what the deploy's
  `release_command` runs, and it is a hard prerequisite for the new code. The
  per-tenant (schema-per-org) migrations no longer run here — they are applied
  off the deploy critical path as background jobs on boot (see
  `Fleetms.TenantMigrations`). `migrate_tenants/0` runs them all synchronously
  for manual/one-off use (`bin/migrate_tenants`). `seed/0` populates a fresh
  database with the demo dataset.
  """
  @app :fleetms

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Migrates every organization's tenant schema synchronously. Normally the
  background jobs handle this; use this for a manual, blocking full run.
  """
  def migrate_tenants do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(Fleetms.Repo, fn _repo ->
        Fleetms.TenantMigrations.migrate_all_tenants()
      end)
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Runs `priv/repo/seeds.exs` against the database. Boots the full app first so Ash
  actions, tenant provisioning and Oban are all available. The seed script itself
  is a no-op when the database already has organizations.
  """
  def seed do
    load_app()
    {:ok, _} = Application.ensure_all_started(@app)
    Code.eval_file(Path.join([:code.priv_dir(@app), "repo", "seeds.exs"]))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
