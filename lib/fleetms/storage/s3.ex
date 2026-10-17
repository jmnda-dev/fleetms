defmodule Fleetms.Storage.S3 do
  @moduledoc """
  S3-compatible object-storage `Fleetms.Storage` adapter (AWS S3, MinIO,
  Cloudflare R2, Backblaze B2, …).

  Select it per environment and point it at a bucket:

      config :fleetms, Fleetms.Storage, adapter: Fleetms.Storage.S3

      config :fleetms, Fleetms.Storage.S3,
        bucket: "my-fleet-bucket",
        # Optional: a public/CDN base URL. When set, `url/2` returns
        # "<public_base_url>/<key>" for public buckets; otherwise it returns a
        # short-lived presigned GET URL.
        public_base_url: "https://cdn.example.com",
        presign_expires_in: 3600

  Credentials, region and (for non-AWS endpoints) host/scheme/port are standard
  `ex_aws` config:

      config :ex_aws,
        access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
        secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"},
        region: "us-east-1"

      # e.g. MinIO / R2 / Backblaze:
      config :ex_aws, :s3, scheme: "https://", host: "...", port: 443, region: "auto"
  """
  @behaviour Fleetms.Storage

  alias Fleetms.Storage

  @impl true
  def put(key, source_path, opts) do
    content_type = opts[:content_type] || MIME.from_path(source_path)
    put_binary(key, File.read!(source_path), content_type: content_type)
  end

  @impl true
  def put_binary(key, contents, opts) do
    key = Storage.validate_key!(key)
    s3_opts = [content_type: opts[:content_type] || "application/octet-stream"]

    case request(ExAws.S3.put_object(bucket(), key, contents, s3_opts)) do
      {:ok, _} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(key) do
    key = Storage.validate_key!(key)

    case request(ExAws.S3.get_object(bucket(), key)) do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key) do
    key = Storage.validate_key!(key)

    case request(ExAws.S3.delete_object(bucket(), key)) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(key, opts) do
    key = Storage.validate_key!(key)

    case public_base_url() do
      nil -> presigned_url(key, opts)
      base -> base <> "/" <> encode_key(key)
    end
  end

  @impl true
  def exists?(key) do
    key = Storage.validate_key!(key)
    match?({:ok, _}, request(ExAws.S3.head_object(bucket(), key)))
  end

  defp presigned_url(key, opts) do
    expires_in = opts[:expires_in] || config()[:presign_expires_in] || 3600

    {:ok, url} =
      ExAws.S3.presigned_url(ExAws.Config.new(:s3), :get, bucket(), key, expires_in: expires_in)

    url
  end

  defp request(operation), do: ExAws.request(operation)

  defp encode_key(key), do: key |> Path.split() |> Enum.map_join("/", &URI.encode/1)

  defp bucket do
    config()[:bucket] ||
      raise ArgumentError, "Fleetms.Storage.S3 requires a :bucket to be configured"
  end

  defp public_base_url, do: config()[:public_base_url]

  defp config, do: Application.get_env(:fleetms, __MODULE__, [])
end
