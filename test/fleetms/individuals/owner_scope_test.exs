defmodule Fleetms.Individuals.OwnerScopeTest do
  @moduledoc """
  The individuals-pool authorization boundary across the owner-scoped resources.

  Inside the shared pool schema each individual client must see only their own
  records; platform staff see everyone; and ordinary business organizations —
  where `owner_id` is always nil — must be completely unaffected. A regression
  here is a cross-client data leak, so these are end to end: real Client role,
  real permissions, real reads. Each resource that adopts `Fleetms.Owned` gets a
  case here.
  """
  use Fleetms.DataCase, async: false

  import Fleetms.{
    FuelFixtures,
    IndividualsFixtures,
    InspectionFixtures,
    IssueFixtures,
    MaintenanceFixtures,
    VehicleFixtures
  }

  alias Fleetms.{FuelManagement, Inspections, Maintenance, Scope, VehicleIssues, VehicleManagement}
  alias Fleetms.Permissions.Sync

  setup :shared_org

  setup do
    # The Client role only grants the view_* permissions once code-declared
    # permissions are synced into public.permissions (Sync is off in test).
    Sync.sync!()
    pool_with_two_clients()
  end

  describe "vehicles" do
    test "each client sees only their own; staff see all", ctx do
      assert_owner_isolated(
        ctx,
        &vehicle_fixture/1,
        &VehicleManagement.list_vehicles!(scope: &1)
      )
    end
  end

  describe "issues" do
    test "each client sees only their own; staff see all", ctx do
      assert_owner_isolated(ctx, &issue_fixture/1, &VehicleIssues.list_issues!(scope: &1))
    end
  end

  describe "work orders" do
    test "each client sees only their own; staff see all", ctx do
      assert_owner_isolated(ctx, &work_order_fixture/1, &Maintenance.list_work_orders!(scope: &1))
    end
  end

  describe "fuel entries" do
    test "each client sees only their own; staff see all", ctx do
      assert_owner_isolated(ctx, &fuel_entry_fixture/1, &FuelManagement.list_fuel_entries!(scope: &1))
    end
  end

  describe "vehicle assignments" do
    test "each client sees only their own; staff see all", ctx do
      assert_owner_isolated(
        ctx,
        &vehicle_assignment_fixture/1,
        &VehicleManagement.list_vehicle_assignments!(scope: &1)
      )
    end
  end

  describe "vehicle renewals" do
    test "each client sees only their own; staff see all", ctx do
      assert_owner_isolated(
        ctx,
        &vehicle_renewal_fixture/1,
        &VehicleManagement.list_vehicle_renewals!(scope: &1)
      )
    end
  end

  describe "service reminders" do
    test "each client sees only their own; staff see all", ctx do
      create = fn scope ->
        vehicle = vehicle_fixture(scope)
        task = service_task_fixture(scope)
        service_reminder_fixture(scope, vehicle, task)
      end

      assert_owner_isolated(ctx, create, &Maintenance.list_service_reminders!(scope: &1))
    end
  end

  describe "inspections" do
    test "each client sees only their own; staff see all", ctx do
      # The form is shared (created by staff); the submissions are what's owned.
      {_form, version} = published_version_fixture(ctx.staff_scope)

      create = fn scope -> inspection_fixture(scope, version) end

      assert_owner_isolated(ctx, create, &Inspections.list_inspections!(scope: &1))
    end
  end

  test "a create through an AshPhoenix.Form stamps the owner (the web path)", ctx do
    # Regression: forms build with `scope:` so the on-behalf context reaches
    # StampOwner. Building with actor/tenant alone dropped it, creating nil-owner
    # records that neither staff nor the client could see.
    scope = Scope.on_behalf_of(ctx.staff_scope, ctx.client_a.id)

    {:ok, vehicle} =
      VehicleManagement.Vehicle
      |> AshPhoenix.Form.for_create(:create, domain: VehicleManagement, scope: scope)
      |> AshPhoenix.Form.submit(params: %{"name" => "Formed", "type" => "Truck"})

    assert vehicle.owner_id == ctx.client_a.id
  end

  test "staff acting on behalf of a client see only that client's records", ctx do
    a = vehicle_fixture(on_behalf(ctx, ctx.client_a))
    b = vehicle_fixture(on_behalf(ctx, ctx.client_b))

    # Even though staff (super-admin) could see everyone, naming a client scopes
    # every read to just that client's fleet.
    as_a = Scope.on_behalf_of(ctx.staff_scope, ctx.client_a.id)
    ids = ids(VehicleManagement.list_vehicles!(scope: as_a))

    assert a.id in ids
    refute b.id in ids
  end

  test "owner scoping does not touch an ordinary business org", %{scope: business_scope} do
    # `scope` is the shared business org's owner. Records here have no owner_id and
    # are visible normally — the pool filter must not apply outside the pool.
    vehicle = vehicle_fixture(business_scope)

    assert is_nil(vehicle.owner_id)
    assert vehicle.id in ids(VehicleManagement.list_vehicles!(scope: business_scope))
  end

  # Creates one record for each client (via staff acting on their behalf), then
  # asserts the owner stamp landed and reads are isolated per client while staff
  # see both.
  defp assert_owner_isolated(ctx, create_fun, list_fun) do
    record_a = create_fun.(on_behalf(ctx, ctx.client_a))
    record_b = create_fun.(on_behalf(ctx, ctx.client_b))

    assert record_a.owner_id == ctx.client_a.id
    assert record_b.owner_id == ctx.client_b.id

    a_ids = ids(list_fun.(ctx.client_a_scope))
    assert record_a.id in a_ids
    refute record_b.id in a_ids

    b_ids = ids(list_fun.(ctx.client_b_scope))
    assert record_b.id in b_ids
    refute record_a.id in b_ids

    staff_ids = ids(list_fun.(ctx.staff_scope))
    assert record_a.id in staff_ids
    assert record_b.id in staff_ids
  end

  defp ids(page), do: page |> results() |> Enum.map(& &1.id)
  defp results(%{results: results}), do: results
  defp results(list) when is_list(list), do: list
end
