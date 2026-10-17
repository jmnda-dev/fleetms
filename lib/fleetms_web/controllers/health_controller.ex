defmodule FleetmsWeb.HealthController do
  @moduledoc """
  A tiny, dependency-free liveness endpoint for platform health checks (Fly).
  Deliberately does no DB work — it only proves the web server is up.
  """
  use FleetmsWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end
end
