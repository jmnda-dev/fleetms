defmodule FleetmsWeb.Billing.LencoWebhookController do
  @moduledoc """
  Receives Lenco's signed collection webhooks. The signature is verified against the
  raw request bytes (cached by `FleetmsWeb.CacheBodyReader`) before the event is
  trusted; a valid `virtual-account.transaction` is matched to its payment and
  settled.

  Lenco only inspects the HTTP status and retries hourly for 24h until acknowledged,
  so we return 200 for anything we've handled or can safely ignore, and a non-2xx
  only for a bad signature or a malformed body (so a real problem keeps retrying).
  """
  use FleetmsWeb, :controller

  alias Fleetms.Billing.Payments
  alias FleetmsWeb.CacheBodyReader

  require Logger

  def create(conn, _params) do
    headers = Map.new(conn.req_headers)
    raw_body = CacheBodyReader.raw_body(conn)

    case Payments.handle_webhook(:lenco, headers, raw_body) do
      {:ok, _payment} ->
        ack(conn, "ok")

      {:error, :invalid_signature} ->
        send_resp(conn, 401, "invalid signature")

      {:error, :event_ignored} ->
        ack(conn, "ignored")

      {:error, :payment_not_found} ->
        Logger.warning("Lenco webhook for unknown payment reference")
        ack(conn, "unknown reference")

      {:error, reason} ->
        Logger.error("Lenco webhook error: #{inspect(reason)}")
        send_resp(conn, 400, "bad request")
    end
  end

  # 200 acknowledges receipt so Lenco stops retrying.
  defp ack(conn, body), do: send_resp(conn, 200, body)
end
