defmodule Fleetms.Accounts.ClientProfileTest do
  @moduledoc """
  KYC profiles are public-schema records only platform staff may touch. These
  cover the onboarding lifecycle (create → verify / reject) and the staff-only
  policy.
  """
  use Fleetms.DataCase, async: false

  alias Fleetms.Accounts

  defp super_admin do
    user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})
  end

  defp profile_attrs(org, overrides \\ %{}) do
    Map.merge(
      %{organization_id: org.id, contact_name: "Jane Client", contact_email: "jane@client.test"},
      overrides
    )
  end

  test "a new profile starts pending" do
    {_owner, org} = user_with_org_fixture()
    admin = super_admin()

    profile = Accounts.create_client_profile!(profile_attrs(org), actor: admin)

    assert profile.status == :pending
    assert profile.organization_id == org.id
    assert is_nil(profile.verified_at)
  end

  test "verifying stamps the time and the acting staff member" do
    {_owner, org} = user_with_org_fixture()
    admin = super_admin()
    profile = Accounts.create_client_profile!(profile_attrs(org), actor: admin)

    verified = Accounts.verify_client_profile!(profile, actor: admin)

    assert verified.status == :verified
    assert verified.verified_at
    assert verified.verified_by_id == admin.id
  end

  test "rejecting clears a prior verification stamp" do
    {_owner, org} = user_with_org_fixture()
    admin = super_admin()

    profile =
      Accounts.create_client_profile!(profile_attrs(org), actor: admin)
      |> then(&Accounts.verify_client_profile!(&1, actor: admin))

    rejected = Accounts.reject_client_profile!(profile, actor: admin)

    assert rejected.status == :rejected
    assert is_nil(rejected.verified_at)
  end

  test "one profile per corporate organization (no owner)" do
    {_owner, org} = user_with_org_fixture()
    admin = super_admin()
    Accounts.create_client_profile!(profile_attrs(org), actor: admin)

    assert_raise Ash.Error.Invalid, fn ->
      Accounts.create_client_profile!(profile_attrs(org), actor: admin)
    end
  end

  test "many owner-scoped profiles can share one org, one per owner" do
    {_owner, pool} = user_with_org_fixture("Individuals Pool")
    admin = super_admin()
    client_a = user_fixture()
    client_b = user_fixture()

    # Two different individual clients, same org — both allowed.
    a = Accounts.create_client_profile!(profile_attrs(pool, %{owner_id: client_a.id}), actor: admin)
    b = Accounts.create_client_profile!(profile_attrs(pool, %{owner_id: client_b.id}), actor: admin)

    assert a.owner_id == client_a.id
    assert b.owner_id == client_b.id
    assert Accounts.get_client_profile_for_owner!(client_a.id, actor: admin).id == a.id

    # ...but the same owner can't have two profiles in that org.
    assert_raise Ash.Error.Invalid, fn ->
      Accounts.create_client_profile!(profile_attrs(pool, %{owner_id: client_a.id}), actor: admin)
    end
  end

  test "non-staff cannot read or create profiles" do
    {owner, org} = user_with_org_fixture()
    admin = super_admin()
    Accounts.create_client_profile!(profile_attrs(org), actor: admin)

    assert Accounts.list_client_profiles!(actor: owner) == []

    assert_raise Ash.Error.Forbidden, fn ->
      Accounts.create_client_profile!(profile_attrs(org), actor: owner)
    end
  end
end
