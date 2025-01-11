defmodule FleetmsWeb.Plugs.RequireServiceProviderUser do
  import Plug.Conn, only: [halt: 1]

  def init(opts), do: opts

  def call(conn, _opts) do
    if user = conn.assigns[:current_user] do
      if user.is_service_provider do
        conn
      else
        raise FleetmsWeb.Exceptions.UnauthorizedError,
              "You are not authorized to perform this action"

        halt(conn)
      end
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      halt(conn)
    end
  end
end
