defmodule FleetmsWeb.CacheBodyReader do
  @moduledoc """
  A `Plug.Parsers` body reader that keeps a copy of the raw request bytes for
  payment-provider webhook routes, so their signatures can be verified against the
  exact payload. Caching is scoped to `/billing/webhooks/*` to avoid holding large
  bodies (e.g. uploads) for every request.

  Wire it in the endpoint: `plug Plug.Parsers, body_reader: {FleetmsWeb.CacheBodyReader, :read_body, []}`.
  Read it back with `FleetmsWeb.CacheBodyReader.raw_body(conn)`.
  """

  @prefix "/billing/webhooks/"

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    conn =
      if String.starts_with?(conn.request_path, @prefix) do
        update_in(conn.assigns[:raw_body], &[body | &1 || []])
      else
        conn
      end

    {:ok, body, conn}
  end

  @doc "The cached raw request body as a binary (empty when nothing was cached)."
  def raw_body(conn) do
    conn.assigns |> Map.get(:raw_body, []) |> Enum.reverse() |> IO.iodata_to_binary()
  end
end
