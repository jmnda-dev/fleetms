defmodule Fleetms.Individuals.PoolTest do
  @moduledoc """
  The individuals pool as internal infrastructure: it is created once, cached,
  flagged, and kept out of the client-facing organization figures.
  """
  use Fleetms.DataCase, async: false

  alias Fleetms.Individuals

  setup do
    on_exit(fn -> Application.delete_env(:fleetms, :individuals_pool_org_id) end)
    :ok
  end

  defp staff, do: user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})

  test "ensure_pool! creates a flagged pool and caches its id" do
    pool = Individuals.ensure_pool!(staff())

    assert pool.individuals_pool?
    assert Individuals.pool?(pool)
    assert Individuals.pool_org_id() == pool.id
    assert Individuals.pool_tenant?("org_#{pool.id}")
  end

  test "ensure_pool! is idempotent — it returns the same pool" do
    admin = staff()
    first = Individuals.ensure_pool!(admin)
    second = Individuals.ensure_pool!(admin)

    assert first.id == second.id
  end

  test "the pool is excluded from the platform organization figures" do
    Individuals.ensure_pool!(staff())
    {_owner, org} = user_with_org_fixture("Real Client Co")

    stats = Fleetms.PlatformStats.overview()

    expected_clients =
      Fleetms.Accounts.list_organizations!(authorize?: false)
      |> Enum.reject(&Individuals.pool?/1)
      |> length()

    # The count matches the non-pool orgs, and the pool never appears in the list.
    assert stats.organizations == expected_clients
    refute Enum.any?(stats.recent_organizations, &Individuals.pool?/1)
    assert Enum.any?(stats.recent_organizations, &(&1.id == org.id))
  end
end
