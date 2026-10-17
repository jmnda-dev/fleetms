defmodule FleetmsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FleetmsWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint FleetmsWeb.Endpoint

      use FleetmsWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import FleetmsWeb.ConnCase
      import Fleetms.AccountsFixtures
      # `setup :shared_org` -> puts :owner, :org, :scope into the test context.
      import Fleetms.SharedTenant, only: [shared_org: 1, shared_org: 0]
    end
  end

  setup tags do
    Fleetms.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Registers a fresh user and returns a conn with that user logged in."
  def register_and_log_in_user(%{conn: conn}) do
    user = Fleetms.AccountsFixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc "Stores `user` in the connection's session so subsequent requests are authenticated."
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
