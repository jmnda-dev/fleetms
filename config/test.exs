import Config
config :fleetms, token_signing_secret: "xFtKzEjYApWqAkSTYP+qhfOFPWsUU7GM"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Tests sync permissions explicitly when needed rather than on every boot.
config :fleetms, sync_permissions_on_boot: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :fleetms, Fleetms.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "fleetms_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fleetms, FleetmsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JJJQm959oV3rDzFreTuMtYZAI7elgxLDFeSacYRRx15O7eXwba/x1+8SyNQupFsy",
  server: false

# In test we don't send emails
config :fleetms, Fleetms.Mailer, adapter: Swoosh.Adapters.Test

# Don't run Oban queues or cron in tests; jobs are exercised by calling their
# logic directly (or via Oban.Testing helpers).
config :fleetms, Oban, testing: :manual

# Feature flags: read straight from the (sandboxed) DB in tests, with no ETS cache
# or cross-node cache-bust, so a flag toggled in one test can't leak into another.
config :fun_with_flags, :cache, enabled: false
config :fun_with_flags, :cache_bust_notifications, enabled: false

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Write test uploads to a throwaway tmp dir, never into priv/static.
config :fleetms, Fleetms.Storage.Local,
  base_dir: Path.join(System.tmp_dir!(), "fleetms_test_uploads"),
  base_url: "/uploads"

# Billing: use placeholder DPO credentials and route the provider's HTTP through a
# Req.Test stub so tests never hit the network. Each test installs its own stub via
# `Req.Test.stub(Fleetms.Billing.Providers.DpoStub, fn conn -> ... end)`.
config :fleetms, Fleetms.Billing,
  dpo: [company_token: "TEST-COMPANY-TOKEN", service_type: "1234"]

config :fleetms, :dpo_req_options, plug: {Req.Test, Fleetms.Billing.Providers.DpoStub}

# Lenco: a placeholder token (so webhook signatures can be computed) and a Req.Test
# stub so the adapter never hits the network.
config :fleetms, Fleetms.Billing, lenco: [api_token: "TEST-LENCO-TOKEN"]
config :fleetms, :lenco_req_options, plug: {Req.Test, Fleetms.Billing.Providers.LencoStub}
