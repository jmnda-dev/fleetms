defmodule Fleetms.ScopeTest do
  use ExUnit.Case, async: true

  alias Fleetms.Accounts.{Organization, User}
  alias Fleetms.Scope

  setup do
    user = %User{id: Ash.UUID.generate()}
    org = %Organization{id: Ash.UUID.generate(), public_id: "abc123def456", name: "Acme"}
    %{user: user, org: org}
  end

  test "new/3 builds a scope", %{user: user, org: org} do
    scope = Scope.new(user, org, true)
    assert scope.user == user
    assert scope.organization == org
    assert scope.owner?
  end

  test "owner?/1 reflects the owner flag", %{user: user, org: org} do
    assert Scope.owner?(Scope.new(user, org, true))
    refute Scope.owner?(Scope.new(user, org, false))
  end

  test "exposes actor and tenant via Ash.Scope.ToOpts", %{user: user, org: org} do
    scope = Scope.new(user, org, false)
    assert {:ok, ^user} = Ash.Scope.ToOpts.get_actor(scope)
    assert {:ok, ^org} = Ash.Scope.ToOpts.get_tenant(scope)
  end
end
