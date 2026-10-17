import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/fleetms start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :fleetms, FleetmsWeb.Endpoint, server: true
end

# Payment provider credentials from the environment (any env). Only applied when a
# token is present, so the dev/test sandbox defaults are left intact otherwise.
if dpo_company_token = System.get_env("DPO_COMPANY_TOKEN") do
  config :fleetms, Fleetms.Billing,
    dpo: [
      company_token: dpo_company_token,
      service_type: System.get_env("DPO_SERVICE_TYPE")
    ]
end

if lenco_api_token = System.get_env("LENCO_API_TOKEN") do
  config :fleetms, Fleetms.Billing,
    lenco: [
      api_token: lenco_api_token,
      base_url: System.get_env("LENCO_BASE_URL") || "https://api.lenco.co/access/v1"
    ]
end

config :fleetms, FleetmsWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :fleetms, Fleetms.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :fleetms, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :fleetms, FleetmsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  config :fleetms,
    token_signing_secret:
      System.get_env("TOKEN_SIGNING_SECRET") ||
        raise("Missing environment variable `TOKEN_SIGNING_SECRET`!")

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :fleetms, FleetmsWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :fleetms, FleetmsWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :fleetms, Fleetms.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

# Outgoing email (optional but needed to actually send). Pick a provider with
# `MAILER_ADAPTER`; left unset, the compile-time default is used (local mailbox in
# dev, a no-op logger in prod — so nothing is sent until this is configured).
#
#   MAILER_ADAPTER=smtp      SMTP_RELAY, SMTP_USERNAME, SMTP_PASSWORD,
#                            SMTP_PORT (default 587), SMTP_TLS (default "if_available"),
#                            SMTP_SSL ("true"/"false", default false)
#   MAILER_ADAPTER=mailgun   MAILGUN_API_KEY, MAILGUN_DOMAIN
#   MAILER_ADAPTER=sendgrid  SENDGRID_API_KEY
#   MAILER_ADAPTER=postmark  POSTMARK_API_KEY
#
# Also set EMAIL_FROM (the address mail is sent from, e.g. no-reply@yourco.com).
mailer_adapter = System.get_env("MAILER_ADAPTER")

if config_env() != :test && mailer_adapter do
  # The API adapters below post over HTTP; Swoosh needs an API client for them.
  config :swoosh, api_client: Swoosh.ApiClient.Req

  case String.downcase(mailer_adapter) do
    "smtp" ->
      config :fleetms, Fleetms.Mailer,
        adapter: Swoosh.Adapters.SMTP,
        relay: System.fetch_env!("SMTP_RELAY"),
        username: System.fetch_env!("SMTP_USERNAME"),
        password: System.fetch_env!("SMTP_PASSWORD"),
        port: String.to_integer(System.get_env("SMTP_PORT", "587")),
        ssl: System.get_env("SMTP_SSL", "false") == "true",
        tls: String.to_atom(System.get_env("SMTP_TLS", "if_available")),
        auth: :always,
        retries: 2

    "mailgun" ->
      config :fleetms, Fleetms.Mailer,
        adapter: Swoosh.Adapters.Mailgun,
        api_key: System.fetch_env!("MAILGUN_API_KEY"),
        domain: System.fetch_env!("MAILGUN_DOMAIN")

    "sendgrid" ->
      config :fleetms, Fleetms.Mailer,
        adapter: Swoosh.Adapters.Sendgrid,
        api_key: System.fetch_env!("SENDGRID_API_KEY")

    "postmark" ->
      config :fleetms, Fleetms.Mailer,
        adapter: Swoosh.Adapters.Postmark,
        api_key: System.fetch_env!("POSTMARK_API_KEY")

    other ->
      raise "Unknown MAILER_ADAPTER #{inspect(other)} — use smtp, mailgun, sendgrid or postmark."
  end
end

# The address transactional email is sent from. Falls back to the built-in default.
if from = System.get_env("EMAIL_FROM") do
  config :fleetms, :email_from, {System.get_env("EMAIL_FROM_NAME", "FleetMS"), from}
end

# Object storage (optional). When `S3_BUCKET` is set, uploads are stored in
# S3-compatible object storage instead of local disk — works with AWS S3, MinIO,
# Cloudflare R2, Backblaze B2, etc. Left unset, the local-disk adapter is used.
s3_bucket = System.get_env("S3_BUCKET")

if config_env() != :test and s3_bucket do
  config :fleetms, Fleetms.Storage, adapter: Fleetms.Storage.S3

  config :fleetms, Fleetms.Storage.S3,
    bucket: s3_bucket,
    # Set for a public bucket / CDN to return plain URLs; otherwise `url/2`
    # returns short-lived presigned URLs.
    public_base_url: System.get_env("S3_PUBLIC_BASE_URL"),
    presign_expires_in: String.to_integer(System.get_env("S3_PRESIGN_EXPIRES_IN") || "3600")

  config :ex_aws,
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
    region: System.get_env("AWS_REGION") || "us-east-1"

  # For non-AWS, S3-compatible endpoints (MinIO / R2 / Backblaze) point ex_aws at
  # the custom host.
  if host = System.get_env("S3_HOST") do
    config :ex_aws, :s3,
      scheme: System.get_env("S3_SCHEME") || "https://",
      host: host,
      port: String.to_integer(System.get_env("S3_PORT") || "443"),
      region: System.get_env("AWS_REGION") || "auto"
  end
end
