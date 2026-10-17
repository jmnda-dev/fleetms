defmodule Fleetms.Billing.Providers.Lenco do
  @moduledoc """
  Lenco adapter — a pay-in provider using **dynamic virtual accounts**.

  Flow: `create_transaction` creates a dynamic virtual account for the payment
  (validated to the exact amount, tagged with our `reference` as its
  `transactionReference`); we show the customer the bank account to transfer into.
  When money arrives, Lenco sends a **signed webhook** (`virtual-account.transaction`)
  which we verify and match back to the payment — this is the confirmation path, so
  there's no polling `verify`.

  REST/JSON with a `Bearer` token. Credentials come from
  `config :fleetms, Fleetms.Billing, lenco: [base_url: ..., api_token: ...]`
  (`LENCO_API_TOKEN` in prod).

  ## Signature verification caveat

  Lenco signs webhooks with `X-Lenco-Signature` = HMAC-SHA512 over the body, keyed
  by the hex SHA-256 of the API token. We verify over the **raw request bytes**
  (the reliable, canonical approach). If live testing shows Lenco signs a
  re-serialized JSON body instead, `verify_signature/2` is the single place to
  adjust. Likewise the exact request/response field names below are from the public
  docs and should be confirmed against a live Lenco account during go-live.
  """
  @behaviour Fleetms.Billing.PaymentProvider

  alias Fleetms.Billing.Payment

  @succeeded_events ~w(virtual-account.transaction virtual-account.transaction.settled transaction.successful)
  @failed_events ~w(virtual-account.rejected-transaction transaction.failed)

  @impl true
  def confirmation_mode, do: :webhook

  @impl true
  def create_transaction(%Payment{} = payment) do
    cfg = config()

    body = %{
      "accountName" => account_name(payment),
      "isStatic" => false,
      "amount" => amount_number(payment.amount),
      "transactionReference" => payment.reference
    }

    with {:ok, data} <- post("/virtual-accounts", body, cfg) do
      {:ok,
       %{
         action: {:instructions, instructions(data)},
         provider_reference: data["id"] || data["accountReference"],
         method: :bank_transfer,
         raw_request: body,
         raw_response: data
       }}
    end
  end

  # Lenco confirms via webhook, not polling.
  @impl true
  def verify_transaction(%Payment{}), do: {:error, :unsupported}

  @impl true
  def parse_webhook(headers, raw_body) do
    if verify_signature(headers, raw_body) do
      interpret(Jason.decode(raw_body))
    else
      {:error, :invalid_signature}
    end
  end

  # --- webhook parsing ---

  defp interpret({:ok, %{"event" => event, "data" => data}}) do
    cond do
      event in @succeeded_events ->
        {:ok,
         %{
           status: :succeeded,
           reference: webhook_reference(data),
           provider_reference: data["id"] || get_in(data, ["virtualAccount", "id"]),
           method: :bank_transfer,
           raw: data
         }}

      event in @failed_events ->
        {:ok,
         %{
           status: :failed,
           reference: webhook_reference(data),
           failure_reason: data["reason"] || "rejected",
           raw: data
         }}

      true ->
        {:error, :event_ignored}
    end
  end

  defp interpret(_), do: {:error, :malformed_payload}

  # Our `reference` comes back as the dynamic account's transactionReference; fall
  # back through the shapes it can appear in.
  defp webhook_reference(data) do
    data["transactionReference"] ||
      get_in(data, ["meta", "transactionReference"]) ||
      get_in(data, ["virtualAccount", "accountReference"]) ||
      data["accountReference"] ||
      data["reference"]
  end

  defp verify_signature(headers, raw_body) do
    provided = headers |> Map.get("x-lenco-signature", "") |> to_string() |> String.downcase()

    case config()[:api_token] do
      token when is_binary(token) and token != "" ->
        key = :sha256 |> :crypto.hash(token) |> Base.encode16(case: :lower)

        expected =
          :hmac |> :crypto.mac(:sha512, key, raw_body) |> Base.encode16(case: :lower)

        provided != "" and Plug.Crypto.secure_compare(expected, provided)

      _ ->
        false
    end
  end

  # --- HTTP ---

  defp post(path, body, cfg) do
    options =
      [
        json: body,
        headers: [{"authorization", "Bearer #{cfg[:api_token]}"}]
      ] ++ Application.get_env(:fleetms, :lenco_req_options, [])

    case Req.post(cfg[:base_url] <> path, options) do
      {:ok, %Req.Response{status: status, body: %{"status" => true, "data" => data}}}
      when status in 200..299 ->
        {:ok, data}

      {:ok, %Req.Response{body: %{"message" => message}}} ->
        {:error, {:lenco_error, message}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:lenco_http_status, status}}

      {:error, reason} ->
        {:error, {:lenco_transport, reason}}
    end
  end

  # --- helpers ---

  defp instructions(data) do
    account = data["bankAccount"] || %{}

    %{
      "bank_name" => get_in(account, ["bank", "name"]),
      "account_number" => account["accountNumber"],
      "account_name" => account["accountName"],
      "currency" => data["currency"],
      "expires_at" => data["expiresAt"],
      "reference" => get_in(data, ["meta", "transactionReference"]) || data["accountReference"]
    }
  end

  defp config, do: Application.get_env(:fleetms, Fleetms.Billing, [])[:lenco] || []

  defp account_name(%Payment{customer_name: name}) when is_binary(name) and name != "", do: name
  defp account_name(%Payment{}), do: "FleetMS subscription"

  defp amount_number(%Money{amount: amount}), do: amount |> Decimal.round(2) |> Decimal.to_float()
end
