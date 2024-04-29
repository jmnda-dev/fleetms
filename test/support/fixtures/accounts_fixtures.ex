defmodule Fleetms.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Fleetms.Accounts` `Ash` domain.
  """

  alias Fleetms.Accounts.{Organization, User}

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "Hello world!5"

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
      |> Ash.create()

    user
  end

  def org_user_fixture(%Organization{id: id}, attrs \\ %{}) do
    attrs =
      Enum.into(%{organization_id: id}, attrs)
      |> valid_org_user_attributes()

    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:organization_internal_user, attrs)
      |> Ash.create()

    user
  end
end
