defmodule FleetmsWeb.ProxyEndpoint do
  use Beacon.ProxyEndpoint,
    otp_app: :fleetms,
    session_options: Application.compile_env!(:fleetms, :session_options),
    fallback: FleetmsWeb.Endpoint
end
