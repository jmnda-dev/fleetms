defmodule FleetmsWeb.Plugs.SetTenant do
  @moduledoc """
  Defines the `FleetmsWeb.Plugs.SetTenant` module, which provides a plug for setting the tenant on a connection.

  This plug is used to set the tenant on a connection based on the value stored in the session. The `get_session/2` function is used to retrieve the tenant value from the session, and the `Ash.set_tenant/1` function is used to set the tenant for the current process. The `Ash.PlugHelpers.set_tenant/2` function is also called to set the tenant on the connection.

  This plug is typically used in conjunction with other plugs to set up the connection for handling requests in a multi-tenant environment. By setting the tenant on the connection, subsequent requests can be processed in the context of the correct tenant.

  The `FleetmsWeb.Plugs.SetTenant` module defines the `init/1` function, which is used to initialize the plug with any options that may be required. The `call/2` function is used to execute the plug, and sets the tenant on the connection.
  """
  import Plug.Conn, only: [get_session: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant = get_session(conn, :tenant)
    Ash.PlugHelpers.set_tenant(conn, tenant)
  end
end
