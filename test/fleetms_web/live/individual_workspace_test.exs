defmodule FleetmsWeb.IndividualWorkspaceTest do
  @moduledoc """
  An individual client is a member of the hidden pool, but must never see the
  internal pool name — the app shows their own name as the workspace instead.
  """
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Fleetms.Permissions.Sync

  setup do
    on_exit(fn -> Application.delete_env(:fleetms, :individuals_pool_org_id) end)
    # The Client role's view_ permissions only resolve once permissions are synced.
    Sync.sync!()
    :ok
  end

  test "an individual sees their own name as the workspace, not the pool name", %{conn: conn} do
    admin = user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})

    {:ok, result} =
      Fleetms.Provisioning.provision_client(
        %{
          account_type: "individual",
          client_email: "chanda-#{System.unique_integer([:positive])}@example.com",
          contact_name: "Chanda Mumba"
        },
        admin
      )

    pool = Fleetms.Individuals.find_pool()

    # Provisioned accounts have no session token yet (they set a password later);
    # mint one so we can drive the session as this individual.
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(result.client_user)
    individual = Ash.Resource.put_metadata(result.client_user, :token, token)

    conn = log_in_user(conn, individual)
    {:ok, _view, html} = live(conn, ~p"/o/#{pool}")

    assert html =~ "Chanda Mumba"
    refute html =~ "Individuals Pool"
  end
end
