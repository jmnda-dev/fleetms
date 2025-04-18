import Config

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
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fleetms, FleetmsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "2V1MyKV1eozeEv9cHZ+bnQQ0pGqk5hKj8Qxe+1I270n78bMpce9xelxfsF/uVHlX",
  server: false

# In test we don't send emails.
config :fleetms, Fleetms.Mailer, adapter: Swoosh.Adapters.Test

config :fleetms,
       :token_signing_secret,
       "SDFOULbu+UdvREQlC3RiEejAVLkv/XDGfLKARryJeP50LokewrrrsKmqxU7btPpo"

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
config :bcrypt_elixir, log_rounds: 1
config :ash, :disable_async?, true
