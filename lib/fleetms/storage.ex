defmodule Fleetms.Storage do
  @moduledoc """
  A storage-agnostic façade for user-uploaded files (vehicle photos and
  documents today; anything tomorrow).

  Callers work entirely in terms of a string `key` — the logical path of an
  object, e.g. `"vehicles/<vehicle_id>/photos/og_front.jpg"`. The configured
  adapter decides where that key physically lives: on local disk in dev/test, in
  S3-compatible object storage in production. Swapping backends is a config
  change, not a code change.

  ## Configuration

      config :fleetms, Fleetms.Storage, adapter: Fleetms.Storage.Local

  Each adapter reads its own settings from its own config key (see
  `Fleetms.Storage.Local`).

  ## Keys

  Keys are caller-defined and should encode whatever namespacing the domain
  wants (tenant, resource, record id). The storage layer treats them opaquely;
  it only refuses keys that try to escape their root (`..` segments).
  """

  @type key :: String.t()
  @type source :: Path.t()

  @doc "Stores the file at `source_path` under `key`. Returns the stored key."
  @callback put(key, source, opts :: keyword) :: {:ok, key} | {:error, term}

  @doc "Stores in-memory `contents` under `key` (e.g. a generated thumbnail)."
  @callback put_binary(key, contents :: binary, opts :: keyword) :: {:ok, key} | {:error, term}

  @doc "Reads the object at `key` into memory."
  @callback get(key) :: {:ok, binary} | {:error, term}

  @doc "Deletes the object at `key`. Missing objects are treated as success."
  @callback delete(key) :: :ok | {:error, term}

  @doc "Returns a URL the browser can fetch the object from."
  @callback url(key, opts :: keyword) :: String.t()

  @doc "Whether an object exists at `key`."
  @callback exists?(key) :: boolean

  @spec put(key, source, keyword) :: {:ok, key} | {:error, term}
  def put(key, source_path, opts \\ []), do: adapter().put(key, source_path, opts)

  @spec put_binary(key, binary, keyword) :: {:ok, key} | {:error, term}
  def put_binary(key, contents, opts \\ []), do: adapter().put_binary(key, contents, opts)

  @spec get(key) :: {:ok, binary} | {:error, term}
  def get(key), do: adapter().get(key)

  @spec delete(key) :: :ok | {:error, term}
  def delete(key), do: adapter().delete(key)

  @spec url(key, keyword) :: String.t()
  def url(key, opts \\ []), do: adapter().url(key, opts)

  @spec exists?(key) :: boolean
  def exists?(key), do: adapter().exists?(key)

  @doc "The configured storage adapter module."
  @spec adapter() :: module()
  def adapter do
    :fleetms
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:adapter, Fleetms.Storage.Local)
  end

  @doc """
  Rejects keys that contain `..` or are absolute, which could escape the storage
  root. Raises `ArgumentError` on an unsafe key, returns it unchanged otherwise.
  Adapters call this before touching the backend.
  """
  @spec validate_key!(key) :: key
  def validate_key!(key) when is_binary(key) do
    segments = Path.split(key)

    if key == "" or String.starts_with?(key, "/") or ".." in segments do
      raise ArgumentError, "unsafe storage key: #{inspect(key)}"
    end

    key
  end
end
