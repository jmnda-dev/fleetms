defmodule Fleetms.Storage.Local do
  @moduledoc """
  Local-filesystem `Fleetms.Storage` adapter — the default in dev and test.

  Objects are written under a base directory and served over HTTP from a base
  URL by a dedicated `Plug.Static` in the endpoint. Both are configurable:

      config :fleetms, Fleetms.Storage.Local,
        base_dir: "/abs/path/to/uploads",   # default: priv/uploads
        base_url: "/uploads"

  `base_dir` defaults to `priv/uploads` inside the app (release-safe via
  `Application.app_dir/2`) — deliberately *outside* `priv/static` so user content
  never goes through the asset pipeline. The matching `Plug.Static` serves it at
  `base_url`.
  """

  @behaviour Fleetms.Storage

  alias Fleetms.Storage

  @impl true
  def put(key, source_path, _opts) do
    dest = path(key)

    with :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- File.cp(source_path, dest) do
      {:ok, key}
    end
  end

  @impl true
  def put_binary(key, contents, _opts) do
    dest = path(key)

    with :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- File.write(dest, contents) do
      {:ok, key}
    end
  end

  @impl true
  def get(key), do: File.read(path(key))

  @impl true
  def delete(key) do
    case File.rm(path(key)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def url(key, _opts) do
    segments = key |> Storage.validate_key!() |> Path.split() |> Enum.map(&URI.encode/1)
    Path.join([base_url() | segments])
  end

  @impl true
  def exists?(key), do: File.exists?(path(key))

  @doc "Absolute on-disk path for `key` (validated against traversal)."
  @spec path(Storage.key()) :: Path.t()
  def path(key), do: Path.join(base_dir(), Storage.validate_key!(key))

  defp base_dir do
    config()[:base_dir] || Application.app_dir(:fleetms, "priv/uploads")
  end

  defp base_url, do: config()[:base_url] || "/uploads"

  defp config, do: Application.get_env(:fleetms, __MODULE__, [])
end
