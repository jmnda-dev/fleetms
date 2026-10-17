ExUnit.start()

# Provision the shared test organization/tenant once, committed, before the
# sandbox takes over so every test can see it. See Fleetms.SharedTenant.
Fleetms.SharedTenant.setup!()

Ecto.Adapters.SQL.Sandbox.mode(Fleetms.Repo, :manual)
