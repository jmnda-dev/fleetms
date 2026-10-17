defmodule Fleetms.ProvisioningTest do
  @moduledoc """
  End-to-end staff provisioning: an organization, its KYC profile, and a
  restricted Client member created in one call.
  """
  use Fleetms.DataCase, async: false

  require Ash.Query

  alias Fleetms.Accounts
  alias Fleetms.Accounts.{Role, UserOrganization}
  alias Fleetms.{Individuals, Provisioning}

  setup do
    on_exit(fn -> Application.delete_env(:fleetms, :individuals_pool_org_id) end)
    :ok
  end

  defp super_admin do
    user_fixture() |> Ash.Seed.update!(%{is_super_admin: true})
  end

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "Client #{System.unique_integer([:positive])}",
        "account_type" => "business",
        "client_email" => "client-#{System.unique_integer([:positive])}@example.com",
        "contact_name" => "Jane Client",
        "reg_number" => "REG-123"
      },
      overrides
    )
  end

  test "provisions an org, a KYC profile and an invited Client member" do
    staff = super_admin()

    assert {:ok, result} = Provisioning.provision_client(attrs(), staff)

    org = result.organization
    assert org.account_type == :business

    # KYC profile recorded, pending review.
    profile = Accounts.get_client_profile!(org.id, actor: staff)
    assert profile.status == :pending
    assert profile.contact_name == "Jane Client"
    assert profile.reg_number == "REG-123"

    # A brand-new email gets an invitation carrying the Client role.
    assert {:invited, invitation} = result.invite
    assert invitation.status == :pending

    client_role =
      Role
      |> Ash.Query.filter(name == "Client" and is_system == true)
      |> Ash.read_one!(authorize?: false, tenant: org)

    assert invitation.role_id == client_role.id
    assert_received {:email, _sent}
  end

  test "the acting staff member owns the org; the client is not an owner" do
    staff = super_admin()

    assert {:ok, %{organization: org}} = Provisioning.provision_client(attrs(), staff)

    owners =
      Accounts.list_user_organizations!(
        query: [filter: [organization_id: org.id, owner?: true]],
        authorize?: false
      )

    assert Enum.map(owners, & &1.user_id) == [staff.id]
  end

  test "an existing account is added directly rather than invited" do
    staff = super_admin()
    existing = user_fixture()

    assert {:ok, result} =
             Provisioning.provision_client(
               attrs(%{"client_email" => to_string(existing.email)}),
               staff
             )

    assert {:added, membership} = result.invite
    assert membership.user_id == existing.id
    refute membership.owner?
  end

  defp individual_attrs(overrides \\ %{}) do
    attrs(Map.merge(%{"account_type" => "individual"}, overrides)) |> Map.delete("name")
  end

  test "provisioning an individual creates their account in the shared pool" do
    staff = super_admin()

    assert {:ok, result} =
             Provisioning.provision_client(
               individual_attrs(%{"client_email" => "chanda@example.test"}),
               staff
             )

    # They join the hidden pool (not a new org), with an account created up front.
    assert Individuals.pool?(result.organization)
    assert {:account_created, client} = result.invite
    assert to_string(client.email) == "chanda@example.test"

    # Added as a non-owner member with the Client role.
    [membership] =
      UserOrganization
      |> Ash.Query.filter(user_id == ^client.id and organization_id == ^result.organization.id)
      |> Ash.read!(authorize?: false)

    refute membership.owner?

    # The KYC profile is scoped to this individual (owner_id), not the whole org.
    assert result.client_profile.owner_id == client.id
    assert Accounts.get_client_profile_for_owner!(client.id, actor: staff).id == result.client_profile.id
  end

  test "two individuals share one pool org, each with their own profile" do
    staff = super_admin()

    {:ok, a} = Provisioning.provision_client(individual_attrs(), staff)
    {:ok, b} = Provisioning.provision_client(individual_attrs(), staff)

    # Same pool org, distinct owners and profiles.
    assert a.organization.id == b.organization.id
    assert a.client_user.id != b.client_user.id
    assert a.client_profile.id != b.client_profile.id
  end

  test "provisioning an individual whose email exists reuses the account" do
    staff = super_admin()
    existing = user_fixture()

    assert {:ok, result} =
             Provisioning.provision_client(
               individual_attrs(%{"client_email" => to_string(existing.email)}),
               staff
             )

    assert {:existing_account, client} = result.invite
    assert client.id == existing.id
    assert result.client_profile.owner_id == existing.id
  end

  test "individual provisioning is rejected when the feature flag is off" do
    staff = super_admin()
    Fleetms.FeatureFlags.disable(:individual_registration)

    assert {:error, :individual_registration_disabled} =
             Provisioning.provision_client(individual_attrs(), staff)

    # Businesses are unaffected.
    assert {:ok, _} = Provisioning.provision_client(attrs(), staff)
  end

  test "requires name, client email and contact name" do
    staff = super_admin()

    assert {:error, {:required, :name}} =
             Provisioning.provision_client(attrs(%{"name" => "  "}), staff)

    assert {:error, {:required, :client_email}} =
             Provisioning.provision_client(attrs(%{"client_email" => ""}), staff)

    assert {:error, {:required, :contact_name}} =
             Provisioning.provision_client(attrs(%{"contact_name" => ""}), staff)
  end

  test "non-staff cannot provision" do
    {owner, _org} = user_with_org_fixture()
    assert {:error, :forbidden} = Provisioning.provision_client(attrs(), owner)
  end
end
