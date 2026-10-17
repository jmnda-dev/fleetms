defmodule Fleetms.Permissions.Cache do
  @moduledoc """
  Cachex-backed store holding all declared permissions from the DSL, keyed by
  permission name. The full set is kept under a single cache entry (it is always
  loaded and replaced as a unit) and lazily populated from
  `Fleetms.Permissions.Manifest.all/0` on first access.
  """

  @cache :fleetms_permissions
  @key :by_name

  @doc false
  def child_spec(_opts) do
    Supervisor.child_spec({Cachex, name: @cache}, id: __MODULE__)
  end

  @spec all() :: [map()]
  def all, do: Map.values(by_name())

  @spec get(atom() | String.t()) :: {:ok, map()} | :error
  def get(name) when is_binary(name), do: Map.fetch(by_name(), name)
  def get(name) when is_atom(name), do: get(to_string(name))

  @spec exists?(atom() | String.t()) :: boolean()
  def exists?(name), do: match?({:ok, _}, get(name))

  @spec reload!() :: :ok
  def reload! do
    Cachex.put(@cache, @key, build_map())
    :ok
  end

  defp by_name do
    case Cachex.fetch(@cache, @key, fn -> {:commit, build_map()} end) do
      {:ok, map} -> map
      {:commit, map} -> map
      _ -> %{}
    end
  end

  defp build_map do
    Fleetms.Permissions.Manifest.all() |> Map.new(fn p -> {p.name, p} end)
  end
end
