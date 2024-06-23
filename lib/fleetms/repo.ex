defmodule Fleetms.Repo do
  use AshPostgres.Repo, otp_app: :fleetms

  def installed_extensions do
    # Ash installs some functions that it needs to run the
    # first time you generate migrations.
    ["ash-functions", "uuid-ossp", "citext"]
  end

  def all_tenants do
    for org <- Fleetms.Accounts.get_all_tenants!() do
      Ash.ToTenant.to_tenant(org, org)
    end
  end
end
