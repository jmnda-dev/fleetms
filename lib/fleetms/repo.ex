defmodule Fleetms.Repo do
  use AshPostgres.Repo, otp_app: :fleetms
  alias Fleetms.Accounts

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext", "pg_trgm", AshMoney.AshPostgresExtension]
  end

  def all_tenants do
    for org <- Accounts.get_all_tenants!() do
      Ash.ToTenant.to_tenant(org, org)
    end
  end

  def min_pg_version do
    %Version{major: 14, minor: 0, patch: 0}
  end
end
