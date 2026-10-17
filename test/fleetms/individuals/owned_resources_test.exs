defmodule Fleetms.Individuals.OwnedResourcesTest do
  @moduledoc """
  Completeness guard for owner-scoping (the individuals pool).

  Owner-scoping is a security boundary: a resource that individual clients own
  but that is missing its `owner_id` filter would leak one client's data to
  another. This test makes that hard to get wrong:

    * exactly the resources we intended are owner-scoped — adding or removing one
      is a conscious change (update `@owned`), so a new user-facing resource can't
      silently ship without a decision about whether individuals own it;
    * every owned resource carries the *full* `Fleetms.Owned` wiring (the stamp
      and the read-narrowing preparation), so none is half-applied.

  Catalogs (service tasks, parts, vendors, inspection form templates) are
  deliberately shared across the pool and must NOT be owner-scoped.
  """
  use ExUnit.Case, async: true

  # The user-facing operational resources isolated per individual client.
  @owned [
    Fleetms.FuelManagement.FuelEntry,
    Fleetms.Inspections.Inspection,
    Fleetms.Maintenance.ServiceReminder,
    Fleetms.Maintenance.WorkOrder,
    Fleetms.VehicleIssues.Issue,
    Fleetms.VehicleManagement.Vehicle,
    Fleetms.VehicleManagement.VehicleAssignment,
    Fleetms.VehicleManagement.VehicleRenewal
  ]

  test "exactly the intended resources are owner-scoped" do
    actual = all_resources() |> Enum.filter(&owner_scoped?/1) |> MapSet.new()

    assert MapSet.equal?(actual, MapSet.new(@owned)), """
    The set of owner-scoped resources changed.

    Expected: #{inspect(Enum.sort(@owned))}
    Actual:   #{inspect(Enum.sort(MapSet.to_list(actual)))}

    If you added a user-facing resource that individual clients own, add
    `fragments: [Fleetms.Owned]` to it and list it in @owned. If it should stay
    shared across the pool (a catalog), don't give it an owner_id.
    """
  end

  test "every owner-scoped resource carries the full Fleetms.Owned wiring" do
    for resource <- @owned do
      assert Ash.Resource.Info.attribute(resource, :owner_id),
             "#{inspect(resource)} is missing its owner_id attribute"

      assert has_module?(
               Ash.Resource.Info.changes(resource),
               & &1.change,
               Fleetms.Individuals.StampOwner
             ),
             "#{inspect(resource)} is missing the StampOwner change"

      assert owner_scoped?(resource),
             "#{inspect(resource)} is missing the ScopeToOwner preparation"
    end
  end

  defp all_resources do
    :fleetms
    |> Application.get_env(:ash_domains, [])
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.uniq()
  end

  # A resource is owner-scoped when it carries the `Fleetms.Owned` fragment, whose
  # signature is the ScopeToOwner preparation. (Note `owner_id` alone isn't enough:
  # ClientProfile has its own owner_id for KYC without being pool-owner-scoped.)
  defp owner_scoped?(resource) do
    has_module?(
      Ash.Resource.Info.preparations(resource),
      & &1.preparation,
      Fleetms.Individuals.ScopeToOwner
    )
  end

  defp has_module?(entries, getter, module) do
    Enum.any?(entries, fn entry -> match?({^module, _}, getter.(entry)) end)
  end
end
