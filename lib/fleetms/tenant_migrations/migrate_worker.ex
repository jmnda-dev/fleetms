defmodule Fleetms.TenantMigrations.MigrateWorker do
  @moduledoc """
  Migrates one tenant schema in the background, off the deploy critical path.

  Enqueued per tenant on boot by `Fleetms.TenantMigrations.enqueue_all/0`. Unique
  per schema for a short window so overlapping deploys/boots don't double up, and
  retried a few times so a transient failure on one tenant doesn't strand it.
  """
  use Oban.Worker,
    queue: :tenant_migrations,
    max_attempts: 3,
    unique: [
      period: 300,
      keys: [:schema],
      # Unique only among incomplete states, so a pending/running migration is
      # never double-enqueued, but the next deploy can enqueue a fresh run.
      states: [:scheduled, :available, :executing, :retryable, :suspended]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"schema" => schema}}) do
    Fleetms.TenantMigrations.migrate_tenant(schema)
  end
end
