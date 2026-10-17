defmodule FleetmsWeb.Plugs.MetricsAuthTest do
  @moduledoc "Covers the optional bearer-token guard on the Prometheus /metrics endpoint."
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias FleetmsWeb.Plugs.MetricsAuth

  @token "s3cr3t-scrape-token"

  defp call(conn), do: MetricsAuth.call(conn, MetricsAuth.init([]))

  defp with_token(token) do
    previous = Application.get_env(:fleetms, :prometheus_metrics_token)
    Application.put_env(:fleetms, :prometheus_metrics_token, token)
    on_exit(fn -> restore(:prometheus_metrics_token, previous) end)
  end

  defp restore(_key, nil), do: Application.delete_env(:fleetms, :prometheus_metrics_token)
  defp restore(_key, value), do: Application.put_env(:fleetms, :prometheus_metrics_token, value)

  describe "when no token is configured" do
    setup do
      with_token(nil)
      :ok
    end

    test "leaves /metrics open" do
      conn = call(conn(:get, "/metrics"))
      refute conn.halted
    end
  end

  describe "when a token is configured" do
    setup do
      with_token(@token)
      :ok
    end

    test "allows /metrics with the correct bearer token" do
      conn =
        conn(:get, "/metrics")
        |> put_req_header("authorization", "Bearer #{@token}")
        |> call()

      refute conn.halted
    end

    test "rejects /metrics with a wrong token" do
      conn =
        conn(:get, "/metrics")
        |> put_req_header("authorization", "Bearer wrong")
        |> call()

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects /metrics with no authorization header" do
      conn = call(conn(:get, "/metrics"))

      assert conn.halted
      assert conn.status == 401
    end

    test "never guards paths other than /metrics" do
      conn =
        conn(:get, "/")
        |> call()

      refute conn.halted
    end
  end
end
