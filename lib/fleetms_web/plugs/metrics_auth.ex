defmodule FleetmsWeb.Plugs.MetricsAuth do
  @moduledoc """
  Guards the Prometheus `/metrics` endpoint with an optional scrape token.

  `PromEx.Plug` serves metrics with no authentication of its own, so this plug
  runs just before it in the endpoint. When a token is configured
  (`:fleetms, :prometheus_metrics_token`, set from `PROMETHEUS_METRICS_TOKEN` in
  `runtime.exs`), requests to `/metrics` must carry `Authorization: Bearer <token>`
  or they get a `401`. When no token is configured — local dev, or a deployment
  that locks the endpoint down at the firewall/proxy instead — `/metrics` is left
  open so scrapers work out of the box.

  Every other request passes through untouched.
  """
  @behaviour Plug
  import Plug.Conn

  @metrics_path "/metrics"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: @metrics_path} = conn, _opts) do
    case Application.get_env(:fleetms, :prometheus_metrics_token) do
      token when is_binary(token) and token != "" -> verify(conn, token)
      _ -> conn
    end
  end

  def call(conn, _opts), do: conn

  defp verify(conn, token) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> presented] ->
        if Plug.Crypto.secure_compare(presented, token) do
          conn
        else
          unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, "unauthorized")
    |> halt()
  end
end
