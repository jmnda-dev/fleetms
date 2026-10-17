defmodule Fleetms.AccountsFixtures do
  @moduledoc """
  Test fixtures for accounts: users, organizations and memberships. Shared by
  both `Fleetms.DataCase` and `FleetmsWeb.ConnCase` tests.
  """

  alias Fleetms.Accounts

  @doc """
  Creates a user with a unique email (authorization bypassed).

  Users are confirmed by default so they represent active accounts that can sign
  in. Pass `confirmed: false` for an unconfirmed user (e.g. to test the gate).
  """
  def user_fixture(attrs \\ %{}) do
    email = Map.get(attrs, :email, "user-#{System.unique_integer([:positive])}@example.com")
    password = Map.get(attrs, :password, "password1234")
    confirmed = Map.get(attrs, :confirmed, true)

    user =
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: password,
        password_confirmation: password
      })
      |> Ash.create!(authorize?: false)

    if confirmed do
      Ash.Seed.update!(user, %{confirmed_at: DateTime.utc_now()})
    else
      user
    end
  end

  @doc "Creates an organization owned by `user` (provisions its tenant schema + roles)."
  def organization_fixture(user, name \\ nil) do
    name = name || "Org #{System.unique_integer([:positive])}"
    Accounts.create_organization!(name, %{owner_user_id: user.id}, actor: user)
  end

  @doc "Creates a confirmed user who owns a fresh organization. Returns `{user, org}`."
  def user_with_org_fixture(name \\ nil) do
    user = user_fixture()
    {user, organization_fixture(user, name)}
  end
end
