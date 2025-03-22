defmodule Fleetms.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FleetmsWeb.Telemetry,
      Fleetms.Repo,
      {DNSCluster, query: Application.get_env(:fleetms, :dns_cluster_query) || :ignore},
      {Beacon, [sites: [Application.fetch_env!(:beacon, :cms)]]},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:fleetms, :ash_domains),
         Application.fetch_env!(:fleetms, Oban)
       )},
      {Phoenix.PubSub, name: Fleetms.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Fleetms.Finch},
      FleetmsWeb.CmsEndpoint,
      # Start a worker by calling: Fleetms.Worker.start_link(arg)
      # {Fleetms.Worker, arg},
      # Start to serve requests, typically the last entry
      FleetmsWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :fleetms]},
      FleetmsWeb.ProxyEndpoint
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
