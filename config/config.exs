# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Timezone database (tz) so datetimes can be shifted into an org's timezone for display.
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

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
  # Ash 3.36+ requires an explicit string-length counting mode. `:mixed` keeps the
  # historical behaviour (byte_size for min, String.length for max), so existing
  # string_length validations and constraints behave exactly as before this upgrade.
  default_string_length_count: :mixed,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec],
  # NOTE: AshMoney.Types.Money is deliberately NOT in `known_types`. Doing so
  # enables Money's operator overloads (e.g. `> [Money, :decimal]`), which Ash then
  # matches against any untyped-left comparison — notably `trigram_similarity(...) >
  # 0.1` in our search preparations — coercing the left side to money and producing
  # `cannot cast type real to money_with_currency`. Money is store-only for now; when
  # a later workstream needs money arithmetic/aggregation in expressions, re-add it
  # here and pin those trigram comparisons with `type(trigram_similarity(...), :float)`.
  custom_types: [money: AshMoney.Types.Money]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :admin,
        :authentication,
        :token,
        :user_identity,
        :postgres,
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
      section_order: [:admin, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

config :fleetms,
  ecto_repos: [Fleetms.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [
    Fleetms.Accounts,
    Fleetms.VehicleManagement,
    Fleetms.VehicleIssues,
    Fleetms.Notifications,
    Fleetms.FuelManagement,
    Fleetms.Inventory,
    Fleetms.Maintenance,
    Fleetms.Inspections,
    Fleetms.Comments,
    Fleetms.Tagging,
    Fleetms.Expenses,
    Fleetms.Drivers,
    Fleetms.Contacts,
    Fleetms.Billing
  ],
  ash_authentication: [return_error_on_invalid_magic_link_token?: true],
  # Per-{user, organization} permission cache TTL, in seconds.
  permission_cache_ttl: 300

# Configure the endpoint
config :fleetms, FleetmsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FleetmsWeb.ErrorHTML, json: FleetmsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Fleetms.PubSub,
  live_view: [signing_salt: "3MSjTNTr"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :fleetms, Fleetms.Mailer, adapter: Swoosh.Adapters.Local

# Oban runs background jobs (e.g. the daily renewal-due digest). Its tables live
# in the public schema; AshOban injects the cron entries for resource triggers and
# scheduled actions via `AshOban.config/2` in the application supervisor. The
# `:notifier` is required so the Cron plugin coordinates across nodes.
config :fleetms, Oban,
  repo: Fleetms.Repo,
  notifier: Oban.Notifiers.PG,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Daily subscription sweep: lapse ended periods into dunning and expire
       # past-due ones after the grace window (see Fleetms.Billing.Lifecycle).
       {"0 2 * * *", Fleetms.Billing.Workers.SweepSubscriptions}
     ]}
  ],
  queues: [
    renewal_digest: 5,
    reminder_digest: 5,
    low_stock_digest: 5,
    inspection_workflows: 10,
    inspection_schedules: 5,
    inspection_digest: 5,
    # Per-tenant schema migrations, enqueued on boot (see Fleetms.TenantMigrations).
    # Kept low so parallel schema DDL doesn't overwhelm the database.
    tenant_migrations: 2,
    # Billing: re-verifying payments with the provider as a safety net.
    billing: 5
  ]

# Payment providers. URLs are static; credentials come from the environment in
# production (config/runtime.exs). Dev/test seed a placeholder DPO sandbox token
# (config/dev.exs, config/test.exs) so the flow is wired end to end — replace it
# with your own active DPO sandbox/live token (DPO rotates public sandbox tokens).
config :fleetms, Fleetms.Billing,
  # Days a past-due subscription stays entitled before it expires.
  grace_days: 7,
  dpo: [
    base_url: "https://secure.3gdirectpay.com/API/v6/",
    checkout_url: "https://secure.3gdirectpay.com/payv3.php",
    company_token: nil,
    service_type: nil
  ],
  lenco: [
    # Confirm the base URL against your Lenco account; the api_token comes from the
    # environment in production (LENCO_API_TOKEN).
    base_url: "https://api.lenco.co/access/v1",
    api_token: nil
  ]

# PromEx: gather app/DB/job/VM metrics and serve them at /metrics for Prometheus.
# We serve /metrics through PromEx.Plug on the normal endpoint (no separate metrics
# web server), and we don't push dashboards to Grafana automatically — export the
# ready-made ones with `mix prom_ex.dashboard.export` and import them by hand.
config :fleetms, Fleetms.PromEx,
  manual_metrics_start_delay: :no_delay,
  metrics_server: :disabled,
  grafana: :disabled

# Feature flags (FunWithFlags). Toggles are persisted in Postgres (public schema)
# and cache-bust across nodes over our existing PubSub, so staff can flip a flag
# at runtime (see /admin/feature-flags) without a redeploy. See Fleetms.FeatureFlags.
config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: Fleetms.Repo

config :fun_with_flags, :cache_bust_notifications,
  enabled: true,
  adapter: FunWithFlags.Notifications.PhoenixPubSub,
  client: Fleetms.PubSub

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  fleetms: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
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

# File storage for user uploads (vehicle photos/documents, etc.). Defaults to
# the local-disk adapter, which writes under priv/static/uploads and is served
# at /uploads by a Plug.Static in the endpoint. Swap the adapter (e.g. to an
# S3-compatible backend) per-environment in prod.exs/runtime.exs.
config :fleetms, Fleetms.Storage, adapter: Fleetms.Storage.Local

# ex_aws (used by the S3 storage adapter) reuses Req as its HTTP client so we
# don't pull in hackney. Credentials/region/bucket are configured per-environment
# (see runtime.exs); nothing here talks to S3 unless the S3 adapter is selected.
config :ex_aws,
  http_client: Fleetms.Storage.S3.ReqClient,
  json_codec: Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
