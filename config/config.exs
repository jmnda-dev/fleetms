# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ash_typescript,
  output_file: "assets/js/ash_rpc.ts",
  run_endpoint: "/rpc/run",
  validate_endpoint: "/rpc/validate",
  input_field_formatter: :camel_case,
  output_field_formatter: :camel_case,
  require_tenant_parameters: false,
  generate_zod_schemas: false,
  generate_phx_channel_rpc_actions: false,
  generate_validation_functions: true,
  zod_import_path: "zod",
  zod_schema_suffix: "ZodSchema",
  phoenix_import_path: "phoenix"

config :ex_cldr, default_backend: Fleetms.Cldr
config :ash_oban, pro?: false

config :fleetms, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10],
  repo: Fleetms.Repo,
  plugins: [{Oban.Plugins.Cron, []}]

config :mime,
  extensions: %{"json" => "application/vnd.api+json"},
  types: %{"application/vnd.api+json" => ["json"]}

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

config :ash,
  allow_forbidden_field_for_relationships_by_default?: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec, AshMoney.Types.Money],
  custom_types: [money: AshMoney.Types.Money]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :account,
        :balance,
        :transfer,
        :admin,
        :authentication,
        :token,
        :user_identity,
        :postgres,
        :json_api,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [
        :admin,
        :json_api,
        :resources,
        :policies,
        :authorization,
        :domain,
        :execution
      ]
    ]
  ]

config :fleetms,
  ecto_repos: [Fleetms.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [Fleetms.Ledger, Fleetms.Accounts]

# Configure the endpoint
config :fleetms, FleetmsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FleetmsWeb.ErrorHTML, json: FleetmsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Fleetms.PubSub,
  live_view: [signing_salt: "3wag5+/B"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :fleetms, Fleetms.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  fleetms: [
    args:
      ~w(js/index.tsx js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/webfonts/* --external:/images/* --alias:@=. --splitting --format=esm),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" =>
        Enum.join(
          [
            Path.expand("../deps", __DIR__),
            Path.expand(Mix.Project.build_path()),
            Path.expand("../_build/dev", __DIR__)
          ],
          ":"
        )
    }
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  fleetms: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
