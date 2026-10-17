defmodule Fleetms.IndividualsFixtures do
  @moduledoc """
  Sets up the individuals pool for owner-scope tests: one hidden pool org (run by
  staff) with two individual clients in it, each holding the Client role.

  `pool_with_two_clients/0` returns the staff/pool/client structs and ready-made
  scopes. Each owner-scoped resource test then creates records for a client with
  `Scope.on_behalf_of(staff_scope, client.id)` and asserts a client sees only
  their own. Requires code-declared permissions to be synced first (so the Client
  role actually grants the view_* permissions) — call `Fleetms.Permissions.Sync.sync!/0`
  in the test setup before using this.
  """
  import Fleetms.AccountsFixtures

  require Ash.Query

  alias Fleetms.Accounts
  alias Fleetms.Accounts.Role
  alias Fleetms.{Individuals, Membership, Scope}

  def pool_with_two_clients do
    staff = user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})

    pool =
      Accounts.create_organization!("Individuals Pool", %{owner_user_id: staff.id}, actor: staff)
      |> Ash.Seed.update!(%{individuals_pool?: true})

    Individuals.put_pool_org_id(pool.id)
    ExUnit.Callbacks.on_exit(fn -> Application.delete_env(:fleetms, :individuals_pool_org_id) end)

    client_a = add_client(pool, staff)
    client_b = add_client(pool, staff)

    %{
      staff: staff,
      pool: pool,
      staff_scope: Scope.new(staff, pool, true),
      client_a: client_a,
      client_b: client_b,
      client_a_scope: Scope.new(client_a, pool, false),
      client_b_scope: Scope.new(client_b, pool, false)
    }
  end

  @doc "A staff scope that stamps records it creates as owned by `client`."
  def on_behalf(%{staff_scope: staff_scope}, client), do: Scope.on_behalf_of(staff_scope, client.id)

  defp add_client(pool, staff) do
    user = user_fixture()
    role = client_role(pool)

    {:ok, :added, _membership} =
      Membership.invite_member(%{email: to_string(user.email), role_id: role.id}, pool, staff)

    user
  end

  defp client_role(pool) do
    Role
    |> Ash.Query.filter(name == "Client" and is_system == true)
    |> Ash.read_one!(authorize?: false, tenant: pool)
  end
end
