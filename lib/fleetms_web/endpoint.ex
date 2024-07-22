defmodule FleetmsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :fleetms
  use Sentry.PlugCapture
  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_fleetms_key",
    signing_salt: "aV2aUtXk",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, longpoll: true, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :fleetms,
    gzip: false,
    only: FleetmsWeb.static_paths()

  if Mix.env() in [:dev, :test] do
    plug Plug.Static,
      at: "/uploads",
      from: Path.expand("./uploads"),
      gzip: false
  else
    plug Plug.Static,
      at: "/uploads",
      # TODO: Refactor this so as to not serve files from the bin directory
      from: "/app/bin/uploads",
      gzip: false
  end

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :fleetms
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Sentry.PlugContext
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug FleetmsWeb.Router
end
