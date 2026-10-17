defmodule Fleetms.TenantMigrations do
  @moduledoc """
  Runs the per-tenant (schema-per-organization) migrations.

  Every organization owns its own Postgres schema (`org_<id>`), so a schema
  change has to be applied once per tenant. Historically the deploy's
  `release_command` did this synchronously for every tenant before the new
  release went live — fine for a handful of orgs, but the fan-out grows linearly
  with tenants and a single slow/failing tenant would hold up the whole deploy.

  Instead the release only migrates the public schema (fast, and a hard
  prerequisite for the new code), and the tenant migrations run **off the deploy
  critical path**: on boot the app enqueues one background job per tenant
  (`MigrateWorker`), so they apply shortly after the release is live, in
  parallel, and retry per tenant without blocking anything else.

  Because tenant migrations are now eventually-applied rather than a deploy gate,
  tenant-schema changes must follow expand/contract: a release must tolerate a
  tenant schema that is one migration behind until its job runs. `migrate_tenant/1`
  is idempotent (only pending migrations run), so jobs are safe to retry and
  re-enqueue.
  """
  @app :fleetms

  require Logger

  @doc "Path to the tenant migrations (`priv/repo/tenant_migrations`)."
  def migrations_path do
    Path.join([:code.priv_dir(@app), "repo", "tenant_migrations"])
  end

  @doc "Every tenant schema name (`org_<id>`), from the repo."
  def all_tenants, do: Fleetms.Repo.all_tenants()

  @doc """
  Brings a single tenant schema up to the latest tenant migration. Idempotent:
  only pending migrations run. The repo must already be started.
  """
  def migrate_tenant(schema) do
    Logger.info("[TenantMigrations] Migrating #{schema}")
    Ecto.Migrator.run(Fleetms.Repo, migrations_path(), :up, all: true, prefix: schema)
    :ok
  end

  @doc """
  Migrates every tenant synchronously, in order. Used for manual/one-off full
  runs (e.g. `bin/migrate_tenants`); the normal path is the background jobs.
  """
  def migrate_all_tenants do
    Enum.each(all_tenants(), &migrate_tenant/1)
    :ok
  end

  @doc """
  Enqueues one background migration job per tenant. The worker is unique per
  schema, so re-enqueuing (e.g. two app instances booting) is a no-op.
  """
  def enqueue_all do
    all_tenants() |> Enum.map(&enqueue/1)
  end

  @doc "Enqueues a background migration job for one tenant schema."
  def enqueue(schema) do
    %{schema: schema}
    |> Fleetms.TenantMigrations.MigrateWorker.new()
    |> Oban.insert()
  end
end
