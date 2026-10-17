defmodule Fleetms.Billing.PaymentProvider do
  @moduledoc """
  The contract every payment gateway adapter implements. Adapters translate
  between our provider-neutral `Fleetms.Billing.Payment` and one gateway's API.

  The gateways differ in shape, so the contract accommodates both:

    * **Redirect providers** (DPO) return a hosted-checkout URL — the customer is
      sent there to pay.
    * **Pay-in providers** (Lenco) return instructions (e.g. a virtual account to
      transfer into) shown to the customer.

  Confirmation is likewise either a **verify** (poll the gateway for status — DPO)
  or a **webhook** (a signed server-to-server event — Lenco). Adapters implement
  whichever apply; the orchestrator (`Fleetms.Billing.Payments`) drives the
  `Payment` state machine and cascades the result to the invoice and subscription.
  """

  alias Fleetms.Billing.Payment

  @typedoc """
  What the adapter got back from initiating a payment.

    * `:action` — `{:redirect, url}` or `{:instructions, map}` for the customer.
    * `:provider_reference` — the gateway's own transaction id/token.
    * `:method` — inferred payment method, if known yet.
    * `:raw_request` / `:raw_response` — snapshots for audit.
  """
  @type handoff :: %{
          required(:action) => {:redirect, String.t()} | {:instructions, map()},
          required(:provider_reference) => String.t() | nil,
          optional(:method) => atom() | nil,
          optional(:raw_request) => map(),
          optional(:raw_response) => map()
        }

  @typedoc """
  A normalized confirmation result (from a verify or a webhook).

    * `:status` — one of `:succeeded | :failed | :pending | :canceled | :expired`.
    * `:reference` — our own payment reference (webhooks carry it back).
  """
  @type result :: %{
          required(:status) => :succeeded | :failed | :pending | :canceled | :expired,
          optional(:reference) => String.t() | nil,
          optional(:provider_reference) => String.t() | nil,
          optional(:method) => atom() | nil,
          optional(:failure_reason) => String.t() | nil,
          optional(:raw) => map()
        }

  @doc "Create the transaction at the gateway and return how to hand the customer off."
  @callback create_transaction(Payment.t()) :: {:ok, handoff()} | {:error, term()}

  @doc "Ask the gateway for a payment's current status (polling confirmation)."
  @callback verify_transaction(Payment.t()) :: {:ok, result()} | {:error, term()}

  @doc """
  Verify and normalize an inbound webhook. `headers` is a plain map of the request
  headers (downcased); `raw_body` is the exact bytes received (needed for signature
  checks). Returns a `result` carrying our `:reference`, or an error.
  """
  @callback parse_webhook(headers :: map(), raw_body :: binary()) ::
              {:ok, result()} | {:error, term()}

  @doc """
  How this provider confirms a payment: `:verify` (we poll — DPO) or `:webhook`
  (the provider pushes a signed event — Lenco). Controls whether `initiate`
  schedules a background verification. Defaults to `:verify` when not implemented.
  """
  @callback confirmation_mode() :: :verify | :webhook

  @optional_callbacks parse_webhook: 2, verify_transaction: 1, confirmation_mode: 0
end
