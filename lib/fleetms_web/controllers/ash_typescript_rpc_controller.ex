defmodule FleetmsWeb.AshTypescriptRpcController do
  use FleetmsWeb, :controller

  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:fleetms, conn, params)
    json(conn, result)
  end

  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:fleetms, conn, params)
    json(conn, result)
  end
end
