defmodule Fleetms.Repo do
  use AshPostgres.Repo,
    otp_app: :fleetms

  @impl true
  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", "citext", "pg_trgm", AshMoney.AshPostgresExtension]
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  def prefer_transaction? do
    false
  end

  @impl true
  def min_pg_version do
    %Version{major: 18, minor: 4, patch: 0}
  end

  # Returns every organization's tenant schema so AshPostgres can run tenant
  # migrations against each one (`mix ash_postgres.migrate --tenants`).
  @impl true
  def all_tenants do
    import Ecto.Query, only: [from: 2]
    all(from(o in "organizations", select: fragment("'org_' || (?)::text", o.id)))
  end
end
