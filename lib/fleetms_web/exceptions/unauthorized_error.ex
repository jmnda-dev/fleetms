defmodule FleetmsWeb.Exceptions.UnauthorizedError do
  defexception [:message, plug_status: 403]
end
