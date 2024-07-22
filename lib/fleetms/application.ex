defmodule Fleetms.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :logger.add_handler(:my_sentry_handler, Sentry.LoggerHandler, %{
        config: %{metadata: [:file, :line]}
      })

    children = [
      # Start the Telemetry supervisor
      FleetmsWeb.Telemetry,
      # Start the Ecto repository
      Fleetms.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Fleetms.PubSub},
      # Start Finch
      {Finch, name: Fleetms.Finch},
      # Start the Endpoint (http/https)
      FleetmsWeb.Endpoint,
      # Start a worker by calling: Fleetms.Worker.start_link(arg)
      # {Fleetms.Worker, arg}
      {AshAuthentication.Supervisor, otp_app: :fleetms}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fleetms.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FleetmsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
