defmodule Fleetms.SharedTenant do
  @moduledoc """
  A single organization (tenant schema) provisioned once for the whole test run
  and shared by feature tests.

  Creating an organization runs the full per-tenant schema migration — slow, and
  (when many run at once) prone to deadlocking on the shared DDL locks. Tests that
  just need *an* organization to work in share this one instead of each creating
  their own. The org and its schema are committed once, before the SQL sandbox
  takes over, so every test's rolled-back transaction can see them; anything a
  test writes inside that org rolls back as usual, so tests stay isolated.

  `setup!/0` is called from `test_helper.exs`. Tests opt in with `setup :shared_org`
  (available via `Fleetms.DataCase`/`FleetmsWeb.ConnCase`), which puts `:owner`,
  `:org` and `:scope` into the test context.

  Tests that specifically exercise organization creation/membership should keep
  creating their own orgs (and run `async: false`).
  """
  require Ash.Query

  alias Fleetms.Accounts
  alias Fleetms.Scope

  @key {__MODULE__, :shared}
  @owner_email "shared-owner@fleetms.test"
  @org_name "Shared Test Org"

  @doc """
  Provisions the shared organization once (idempotent across runs) and caches the
  owner + org structs. Must run before the Ecto sandbox is put in `:manual` mode
  so the writes commit.
  """
  def setup! do
    {user, org} = find_or_create()
    :persistent_term.put(@key, {user, org})
    :ok
  end

  @doc "The cached `{owner_user, organization}` for the shared tenant."
  def fetch, do: :persistent_term.get(@key)

  @doc "A `Fleetms.Scope` for the shared org's owner (all permissions)."
  def scope do
    {user, org} = fetch()
    Scope.new(user, org, true)
  end

  @doc """
  A `setup` callback: merges `:owner`, `:org` and `:scope` into the test context.

      setup :shared_org
  """
  def shared_org(_context \\ %{}) do
    {user, org} = fetch()
    %{owner: user, org: org, scope: Scope.new(user, org, true)}
  end

  # Reused across runs (idempotent by owner email). A tenant's schema is migrated
  # only when first created, so the `mix test` alias runs `ash_postgres.migrate
  # --tenants` beforehand to bring an existing shared tenant up to the current
  # migrations.
  defp find_or_create do
    case existing_owner() do
      nil ->
        user = create_owner()
        org = Accounts.create_organization!(@org_name, %{owner_user_id: user.id}, actor: user)
        {user, org}

      user ->
        {user, owned_org(user)}
    end
  end

  defp existing_owner do
    case Accounts.get_user_by_email(@owner_email, authorize?: false) do
      {:ok, user} -> user
      _ -> nil
    end
  end

  defp create_owner do
    user =
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: @owner_email,
        password: "password1234",
        password_confirmation: "password1234"
      })
      |> Ash.create!(authorize?: false)

    Ash.Seed.update!(user, %{confirmed_at: DateTime.utc_now()})
  end

  defp owned_org(user) do
    Accounts.UserOrganization
    |> Ash.Query.filter(user_id == ^user.id and owner? == true)
    |> Ash.Query.load(:organization)
    |> Ash.read_one!(authorize?: false)
    |> Map.fetch!(:organization)
  end
end
