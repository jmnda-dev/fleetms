defmodule Fleetms.DashboardOwnerScopeTest do
  @moduledoc """
  The dashboard counts run with `authorize?: false`, so in the shared individuals
  pool they must be owner-scoped explicitly — otherwise a client would see
  pool-wide totals across every other client. This guards that boundary.
  """
  use Fleetms.DataCase, async: false

  import Fleetms.{IndividualsFixtures, VehicleFixtures}

  alias Fleetms.{Dashboard, Scope}

  setup :shared_org

  defp vehicle_total(summary), do: summary.vehicle_status |> Map.values() |> Enum.sum()

  test "in the pool, the dashboard counts only the client's own vehicles" do
    ctx = pool_with_two_clients()
    vehicle_fixture(on_behalf(ctx, ctx.client_a))
    vehicle_fixture(on_behalf(ctx, ctx.client_b))
    vehicle_fixture(on_behalf(ctx, ctx.client_b))

    # Each individual sees only their own count, never the pool-wide 3.
    assert vehicle_total(Dashboard.summary(ctx.client_a_scope)) == 1
    assert vehicle_total(Dashboard.summary(ctx.client_b_scope)) == 2

    # Staff managing a client see that client's count.
    as_a = Scope.on_behalf_of(ctx.staff_scope, ctx.client_a.id)
    assert vehicle_total(Dashboard.summary(as_a)) == 1
  end

  test "an ordinary business org counts its whole fleet (no owner filter)", %{scope: scope} do
    before = vehicle_total(Dashboard.summary(scope))
    vehicle_fixture(scope)
    vehicle_fixture(scope)

    # Not the pool → no owner filter; both vehicles are counted for the org.
    assert vehicle_total(Dashboard.summary(scope)) == before + 2
  end
end
