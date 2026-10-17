defmodule Fleetms.Individuals do
  @moduledoc """
  The "individuals pool": one hidden internal organization whose single tenant
  schema is shared by every individual (personal-fleet) client.

  Unlike a corporate client — which gets its own organization and therefore its
  own Postgres schema — individual clients are all *members* of this one pool org.
  Inside its schema they are separated only by authorization: each user-facing
  record carries an `owner_id`, and the `Fleetms.Individuals.OwnerCheck` policy
  filters reads to the current client's own rows (see `Fleetms.Owned`). Platform
  staff (super-admins) and every other organization are unaffected.

  Because the wall between individuals is a policy rather than a schema, code must
  be able to ask cheaply "is the current tenant the pool?". The pool's
  organization id is held in application env (`:individuals_pool_org_id`) — set
  from the database on boot and whenever the pool is created — so the check never
  touches the database on the hot path.
  """

  require Ash.Query

  alias Fleetms.Accounts.Organization

  @env_key :individuals_pool_org_id
  @pool_name "Individuals Pool"

  @doc "The pool organization's id, or `nil` if the pool doesn't exist yet."
  def pool_org_id, do: Application.get_env(:fleetms, @env_key)

  @doc "Whether `org` is the hidden individuals pool (not a real client org)."
  def pool?(%Organization{individuals_pool?: true}), do: true
  def pool?(_), do: false

  @doc """
  The client whose owner-scoped rows a scope should see inside the pool: the one
  staff are managing (`on_behalf_of`), or the individual themselves. Returns nil
  outside the pool, and for staff viewing the pool with no client selected (they
  get the unfiltered, pool-wide view). Used to owner-scope the `authorize?: false`
  reporting queries (dashboard, reports) that the schema alone doesn't isolate.
  """
  def acting_owner_id(%{organization: org} = scope) do
    cond do
      not pool?(org) -> nil
      scope.on_behalf_of -> scope.on_behalf_of
      scope.user && not scope.user.is_super_admin -> scope.user.id
      true -> nil
    end
  end

  def acting_owner_id(_), do: nil

  @doc """
  Finds the individuals pool, creating it (owned by `owner`, a staff user) if it
  doesn't exist yet, and caches its id. Idempotent. `owner` may be a `User` struct
  or a user id.
  """
  def ensure_pool!(owner) do
    pool = find_pool() || create_pool!(user_id(owner))
    put_pool_org_id(pool.id)
    pool
  end

  defp user_id(%{id: id}), do: id
  defp user_id(id) when is_binary(id), do: id

  defp create_pool!(owner_user_id) do
    Fleetms.Accounts.create_organization!(@pool_name, %{owner_user_id: owner_user_id},
      authorize?: false
    )
    |> Ash.Seed.update!(%{individuals_pool?: true})
  end

  @doc "Records the pool organization's id in application env (idempotent)."
  def put_pool_org_id(id), do: Application.put_env(:fleetms, @env_key, id)

  @doc """
  Whether `tenant` is the individuals pool's schema. Accepts the tenant string
  (`\"org_<id>\"`) or an `Organization` struct; anything else is not the pool.
  """
  def pool_tenant?(tenant) do
    case pool_org_id() do
      nil -> false
      id -> tenant_string(tenant) == "org_#{id}"
    end
  end

  defp tenant_string("org_" <> _ = schema), do: schema
  defp tenant_string(%Organization{id: id}), do: "org_#{id}"
  defp tenant_string(_), do: nil

  @doc """
  Loads the pool organization's id from the database into application env, if a
  pool exists. Safe to call on boot before migrations have created the column.
  """
  def configure_from_db do
    case find_pool() do
      %Organization{id: id} -> put_pool_org_id(id)
      nil -> :ok
    end
  rescue
    _ -> :ok
  end

  @doc "The pool organization, or `nil`. Reads the database (not the hot path)."
  def find_pool do
    Organization
    |> Ash.Query.filter(individuals_pool? == true)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
