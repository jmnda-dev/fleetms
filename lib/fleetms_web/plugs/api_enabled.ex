defmodule FleetmsWeb.Plugs.ApiEnabled do
  @moduledoc """
  Global kill-switch for the public JSON:API. When the `:public_api` feature flag
  is off, every data endpoint under `/api/v1` returns 503 — a way for platform
  staff to disable the REST API (incident response, maintenance) without a deploy.
  The docs and token sign-in are unaffected; only the authenticated data pipeline
  mounts this plug.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Fleetms.FeatureFlags.public_api?() do
      conn
    else
      body =
        Jason.encode!(%{errors: [%{status: "503", detail: "The API is temporarily disabled."}]})

      conn
      |> put_resp_content_type("application/vnd.api+json")
      |> send_resp(503, body)
      |> halt()
    end
  end
end
