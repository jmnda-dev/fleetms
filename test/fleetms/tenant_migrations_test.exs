defmodule Fleetms.TenantMigrationsTest do
  @moduledoc """
  The background tenant-migration wiring: discovering tenants and enqueuing one
  deduplicated job per tenant. The migrator run itself is Ecto's, exercised by the
  real migrate path (and the `mix test` tenant migration), not re-run in the
  sandbox here.
  """
  use Fleetms.DataCase, async: false
  use Oban.Testing, repo: Fleetms.Repo

  alias Fleetms.TenantMigrations
  alias Fleetms.TenantMigrations.MigrateWorker

  setup :shared_org

  test "all_tenants includes the current org schemas", %{org: org} do
    assert "org_#{org.id}" in TenantMigrations.all_tenants()
  end

  test "migrations_path points at the tenant migrations" do
    assert String.ends_with?(TenantMigrations.migrations_path(), "repo/tenant_migrations")
  end

  test "enqueue_all enqueues a migration job per tenant", %{org: org} do
    TenantMigrations.enqueue_all()

    assert_enqueued(
      worker: MigrateWorker,
      queue: :tenant_migrations,
      args: %{schema: "org_#{org.id}"}
    )
  end

  test "enqueue is unique per schema", %{org: org} do
    schema = "org_#{org.id}"

    assert {:ok, job1} = TenantMigrations.enqueue(schema)
    assert {:ok, job2} = TenantMigrations.enqueue(schema)

    # The second insert collapses onto the first rather than double-scheduling.
    assert job1.id == job2.id
  end
end
