defmodule Fleetms.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FleetmsWeb.Telemetry,
      # Gathers Prometheus metrics (see Fleetms.PromEx); served at /metrics.
      Fleetms.PromEx,
      Fleetms.Repo,
      {DNSCluster, query: Application.get_env(:fleetms, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Fleetms.PubSub},
      # Permission caches must be started before any web/auth processes that
      # perform authorization checks.
      Fleetms.Permissions.Cache,
      Fleetms.Permissions.UserCache,
      {Task.Supervisor, name: Fleetms.TaskSupervisor},
      # AshOban injects the cron schedule for resource triggers/scheduled actions
      # (e.g. the daily renewal digest) into the base Oban config.
      {Oban,
       AshOban.config(
         Application.fetch_env!(:fleetms, :ash_domains),
         Application.fetch_env!(:fleetms, Oban)
       )},
      # Start to serve requests, typically the last entry
      FleetmsWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :fleetms]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fleetms.Supervisor]
    result = Supervisor.start_link(children, opts)

    maybe_sync_permissions()
    maybe_migrate_tenants()
    # Cache the individuals-pool org id (if the pool exists) for the owner-scope checks.
    Fleetms.Individuals.configure_from_db()
    # Seed default feature-flag values (only for flags not yet set).
    Fleetms.FeatureFlags.ensure_defaults!()

    result
  end

  # Apply per-tenant schema migrations off the deploy critical path: enqueue one
  # background job per tenant shortly after boot. Enabled in prod (the deploy's
  # release_command migrates only the public schema); off elsewhere, where the
  # dev/test flows migrate tenants directly. See `Fleetms.TenantMigrations`.
  defp maybe_migrate_tenants do
    if Application.get_env(:fleetms, :migrate_tenants_on_boot, false) do
      Task.Supervisor.start_child(Fleetms.TaskSupervisor, fn ->
        try do
          Fleetms.TenantMigrations.enqueue_all()
        rescue
          error ->
            require Logger
            Logger.warning(
              "[TenantMigrations] Skipped enqueue on boot: #{Exception.message(error)}"
            )
        end
      end)
    end
  end

  # Sync code-declared permissions into the database asynchronously after boot.
  # Skipped in test (tests sync explicitly when needed) and tolerant of a missing
  # `permissions` table before migrations have run.
  defp maybe_sync_permissions do
    if Application.get_env(:fleetms, :sync_permissions_on_boot, true) do
      Task.Supervisor.start_child(Fleetms.TaskSupervisor, fn ->
        try do
          Fleetms.Permissions.Sync.sync!()
          # Re-grant newly-added permissions to existing orgs' system roles.
          Fleetms.Permissions.Seeder.sync_all_system_roles!()
        rescue
          error ->
            require Logger
            Logger.warning("[Permissions.Sync] Skipped on boot: #{Exception.message(error)}")
        end
      end)
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FleetmsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
