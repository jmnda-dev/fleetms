defmodule Fleetms.PromEx do
  @moduledoc """
  Collects metrics about the running app and exposes them for Prometheus/Grafana.

  Phoenix, Ecto, Oban, LiveView and the Erlang VM all emit `:telemetry` events as
  they work (a request finished, a query ran, a job succeeded, memory changed).
  PromEx listens to those events, keeps running tallies in memory, and serves them
  as plain text at `/metrics` (wired up by `PromEx.Plug` in the endpoint). A
  Prometheus server scrapes that URL every few seconds and stores the numbers over
  time; Grafana then draws the graphs.

  The `plugins/0` list is what we measure; each built-in plugin knows which
  telemetry events to listen for and turns them into named metrics. The
  `dashboards/0` list points at ready-made Grafana dashboards shipped by PromEx —
  export them with `mix prom_ex.dashboard.export --dashboard <name>.json --stdout`
  and import the JSON into Grafana.
  """
  use PromEx, otp_app: :fleetms

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # The app itself — version, uptime, dependency info.
      Plugins.Application,
      # The Erlang VM — memory, process/atom counts, run queues, GC, scheduler load.
      Plugins.Beam,
      # HTTP: request rate, response time, status codes, per-route breakdown.
      {Plugins.Phoenix, router: FleetmsWeb.Router, endpoint: FleetmsWeb.Endpoint},
      # Database: query time (queue/decode/execute), and connection-pool pressure.
      {Plugins.Ecto, repos: [Fleetms.Repo]},
      # Background jobs: how many ran, succeeded, failed, and how long they took.
      Plugins.Oban,
      # LiveView: mount, handle_event and handle_params durations.
      Plugins.PhoenixLiveView
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"},
      {:prom_ex, "phoenix_live_view.json"}
    ]
  end
end
