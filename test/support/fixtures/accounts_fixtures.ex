defmodule Fleetms.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Fleetms.Accounts` `Ash` domain.
  """

  alias Fleetms.Accounts.{Organization, User}

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "Hello2theWorld!"

  def valid_organization_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Fleetms Org"
    })
  end

  def valid_initial_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      password_confirmation: valid_user_password(),
      user_profile: valid_user_profile_attributes(),
      organization: valid_organization_attributes()
    })
  end

  def valid_org_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      password_confirmation: valid_user_password(),
      user_profile: valid_user_profile_attributes()
    })
  end

  def valid_user_profile_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      first_name: "John",
      last_name: "Doe"
    })
  end

  def initial_user_fixture(attrs \\ %{}) do
    attrs = valid_initial_user_attributes(attrs)

    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:register_with_password, attrs)
      # Set the `ash_authentication?: true` in context to make the `AshAuthentication.Checks.AshAuthenticationInteraction` policy in the User resource pass.
      |> Ash.Changeset.set_context(%{private: %{ash_authentication?: true}})
      |> Ash.create()

    Ash.load!(user, [:full_name, :organization])
  end

  def org_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:create_organization_user, valid_org_user_attributes(attrs))
      # Set the `ash_authentication?: true` in context to make the `AshAuthentication.Checks.AshAuthenticationInteraction` policy in the User resource pass.
      |> Ash.Changeset.set_context(%{private: %{ash_authentication?: true}})
      |> Ash.create()

    Ash.load!(user, :full_name)
  end

  def organization_fixture(attrs \\ %{}) do
    merged_attrs =
      Enum.into(attrs, valid_organization_attributes())

    {:ok, organization} =
      Organization
      |> Ash.Changeset.for_create(:create, merged_attrs)
      |> Ash.create()

    organization
  end

  def setup_organization_and_user do
    initial_user = initial_user_fixture()
    %{user: initial_user, tenant: initial_user.organization}
  end
end
