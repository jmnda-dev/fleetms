# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :fleetms,
  ecto_repos: [Fleetms.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :fleetms, FleetmsWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: FleetmsWeb.ErrorHTML, json: FleetmsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Fleetms.PubSub,
  live_view: [signing_salt: "9Pz72d98"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :fleetms, Fleetms.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js js/public-pages.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :spark, :formatter,
  remove_parens?: true,
  "Ash.Resource": [
    type: Ash.Resource,
    section_order: [
      :authentication,
      :token,
      :attributes,
      :relationships,
      :policies,
      :postgres
    ]
  ]

config :ash, :known_types, [AshMoney.Types.Money]

config :fleetms,
  ash_domains: [
    Fleetms.Accounts,
    Fleetms.Common,
    Fleetms.VehicleManagement,
    Fleetms.VehicleInspection,
    Fleetms.VehicleIssues,
    Fleetms.Inventory,
    Fleetms.VehicleMaintenance,
    Fleetms.FuelManagement
  ]

config :waffle,
  storage: Waffle.Storage.Local

config :ex_cldr,
  default_locale: "en",
  default_backend: Fleetms.Cldr

config :ex_money,
  default_currency: :ZMW

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: Fleetms.Repo

config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: Fleetms.PubSub

config :fleetms, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, mailers: 20, vehicle_general_reminders: 50],
  repo: Fleetms.Repo,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Runs Daily
       {"0 0 * * *", Fleetms.VehicleManagement.Workers.UpdateVehicleGeneralReminderStatuses}
     ]}
  ]

config :live_toast,
  gettext_backend: FleetmsWeb.Gettext
# config :ash, :policies, log_successful_policy_breakdowns: :error
# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.

#config :phoenix_analytics,
#  duckdb_path: System.get_env("DUCKDB_PATH") || "analytics.duckdb",
#  app_domain: System.get_env("PHX_HOST") || "example.com"

import_config "#{config_env()}.exs"
