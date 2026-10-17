defmodule Fleetms.Permissions.UserCache do
  @moduledoc """
  Caches each user's effective permissions per `{user_id, tenant}` with a TTL,
  avoiding a DB round-trip on every authorization check. Backed by Cachex, which
  handles per-key expiry and eviction natively.

  Each entry records whether the user is the organization *owner* (a per-org
  super-admin who is granted every permission) alongside the explicit permission
  name set derived from their assigned roles.

  Invalidate via `invalidate/2` when a user's roles or org membership change.
  """
  require Ash.Query

  @cache :fleetms_user_permissions
  @default_ttl_seconds 300

  @doc false
  def child_spec(_opts) do
    Supervisor.child_spec({Cachex, name: @cache}, id: __MODULE__)
  end

  @doc "Returns `{owner?, MapSet.t(permission_name)}` for a user in a tenant."
  @spec get_or_load(binary(), term()) :: {boolean(), MapSet.t(String.t())}
  def get_or_load(user_id, tenant) do
    schema = schema_name(tenant)
    key = {user_id, schema}
    expire = ttl_seconds() * 1000

    case Cachex.fetch(@cache, key, fn ->
           {:commit, load_from_db(user_id, schema), expire: expire}
         end) do
      {:ok, value} -> value
      {:commit, value} -> value
      _ -> {false, MapSet.new()}
    end
  end

  @spec has_permission?(binary(), term(), String.t()) :: boolean()
  def has_permission?(user_id, tenant, permission_name) do
    {owner?, permissions} = get_or_load(user_id, tenant)
    owner? or MapSet.member?(permissions, permission_name)
  end

  @spec invalidate(binary(), term()) :: :ok
  def invalidate(user_id, tenant) do
    Cachex.del(@cache, {user_id, schema_name(tenant)})
    :ok
  end

  @spec invalidate_all_for_user(binary()) :: :ok
  def invalidate_all_for_user(user_id) do
    case Cachex.keys(@cache) do
      {:ok, keys} ->
        Enum.each(keys, fn
          {^user_id, _schema} = key -> Cachex.del(@cache, key)
          _ -> :ok
        end)

      _ ->
        :ok
    end

    :ok
  end

  defp ttl_seconds do
    Application.get_env(:fleetms, :permission_cache_ttl, @default_ttl_seconds)
  end

  defp load_from_db(user_id, schema) do
    owner? = owner?(user_id, schema)

    permissions =
      Fleetms.Accounts.UserRole
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.load(role: [:permissions])
      |> Ash.read!(tenant: schema, authorize?: false)
      |> Enum.flat_map(fn ur -> ur.role.permissions end)
      |> Enum.map(& &1.name)
      |> MapSet.new()

    {owner?, permissions}
  rescue
    _ -> {false, MapSet.new()}
  end

  defp owner?(user_id, schema) do
    case org_id_from_tenant(schema) do
      nil ->
        false

      org_id ->
        Fleetms.Accounts.UserOrganization
        |> Ash.Query.filter(user_id == ^user_id and organization_id == ^org_id and owner? == true)
        |> Ash.read!(authorize?: false)
        |> Enum.any?()
    end
  end

  defp org_id_from_tenant("org_" <> id), do: id
  defp org_id_from_tenant(tenant) when is_binary(tenant), do: tenant
  defp org_id_from_tenant(_), do: nil

  # Normalize any accepted tenant form to the canonical schema string `org_<id>`,
  # so cache keys are stable across struct/string call sites.
  defp schema_name(%Fleetms.Accounts.Organization{id: id}), do: "org_#{id}"
  defp schema_name("org_" <> _ = schema), do: schema
  defp schema_name(id) when is_binary(id), do: "org_#{id}"
  defp schema_name(other), do: other
end
