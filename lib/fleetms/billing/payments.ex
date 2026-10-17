defmodule Fleetms.Billing.Payments do
  @moduledoc """
  Orchestrates a payment through its provider: initiating the handoff, applying a
  confirmation (from a verify or a webhook) to the `Payment` state machine, and
  cascading a success to its invoice and subscription.

  This is the provider-neutral seam — it picks the adapter from `payment.provider`
  and speaks only in `Fleetms.Billing.PaymentProvider` terms. It always runs as the
  system (`authorize?: false`): callers are webhooks, the return handler, and the
  Oban verify job, none of which have a user actor.
  """

  alias Fleetms.Billing
  alias Fleetms.Billing.Payment
  alias Fleetms.Billing.Workers.VerifyPayment

  @verify_delay_seconds 120

  @doc """
  Initiate a pending payment with its provider. Records the handoff (checkout URL or
  pay-in instructions) on the payment and, for verify-based providers, schedules a
  background verification as a safety net for a missed return.
  """
  @spec initiate(Payment.t()) :: {:ok, Payment.t()} | {:error, term()}
  def initiate(%Payment{provider: provider} = payment) do
    module = provider_module(provider)

    with {:ok, handoff} <- module.create_transaction(payment),
         {:ok, payment} <-
           Billing.start_payment_processing(payment, handoff_attrs(handoff), authorize?: false) do
      if confirmation_mode(module) == :verify, do: schedule_verify(payment)
      {:ok, payment}
    end
  end

  @doc """
  Verify and apply an inbound provider webhook. Returns the settled payment, or a
  specific error the controller maps to an HTTP status: `:invalid_signature`,
  `:event_ignored`, or `:payment_not_found`.
  """
  @spec handle_webhook(atom(), map(), binary()) :: {:ok, Payment.t()} | {:error, term()}
  def handle_webhook(provider, headers, raw_body) do
    module = provider_module(provider)

    with {:ok, %{reference: reference} = result} when is_binary(reference) <-
           module.parse_webhook(headers, raw_body),
         {:ok, payment} <- fetch_payment(reference) do
      apply_result(payment, result)
    else
      {:ok, %{}} -> {:error, :event_ignored}
      other -> other
    end
  end

  @doc "Verify a payment's status with its provider and apply the result."
  @spec verify(Payment.t() | String.t()) :: {:ok, Payment.t()} | {:error, term()}
  def verify(%Payment{provider: provider} = payment) do
    module = provider_module(provider)

    with {:ok, result} <- module.verify_transaction(payment) do
      apply_result(payment, result)
    end
  end

  def verify(payment_id) when is_binary(payment_id) do
    verify(Billing.get_payment!(payment_id, authorize?: false))
  end

  @doc """
  Apply a normalized confirmation `result` to a payment: transition its state and,
  on success, mark the invoice paid and activate/renew the subscription. Idempotent
  — a payment already in a terminal state is left untouched.
  """
  @spec apply_result(Payment.t(), Fleetms.Billing.PaymentProvider.result()) ::
          {:ok, Payment.t()} | {:error, term()}
  def apply_result(%Payment{status: status} = payment, _result)
      when status in [:succeeded, :failed, :canceled, :expired] do
    {:ok, payment}
  end

  def apply_result(%Payment{} = payment, %{status: :succeeded} = result) do
    with {:ok, payment} <-
           Billing.succeed_payment(
             payment,
             %{
               provider_reference: result[:provider_reference],
               method: result[:method],
               raw_response: result[:raw]
             },
             authorize?: false
           ) do
      payment = Ash.load!(payment, [:invoice, :subscription], authorize?: false)
      settle_invoice(payment.invoice)
      settle_subscription(payment.subscription)
      {:ok, payment}
    end
  end

  def apply_result(%Payment{} = payment, %{status: :failed} = result) do
    Billing.fail_payment(
      payment,
      %{failure_reason: result[:failure_reason], raw_response: result[:raw]},
      authorize?: false
    )
  end

  def apply_result(%Payment{} = payment, %{status: :canceled}),
    do: Billing.cancel_payment(payment, authorize?: false)

  def apply_result(%Payment{} = payment, %{status: :expired}),
    do: Billing.expire_payment(payment, authorize?: false)

  # Still pending — nothing to do; a later verify/webhook will settle it.
  def apply_result(%Payment{} = payment, %{status: :pending}), do: {:ok, payment}

  @doc "The adapter module for a provider."
  @spec provider_module(atom()) :: module()
  def provider_module(:dpo), do: Fleetms.Billing.Providers.Dpo
  def provider_module(:lenco), do: Fleetms.Billing.Providers.Lenco

  def provider_module(other),
    do: raise(ArgumentError, "no payment provider adapter for #{inspect(other)}")

  # --- internal ---

  defp handoff_attrs(%{action: action} = handoff) do
    %{
      provider_reference: handoff[:provider_reference],
      method: handoff[:method],
      raw_request: handoff[:raw_request],
      raw_response: handoff[:raw_response]
    }
    |> Map.merge(action_attrs(action))
  end

  defp action_attrs({:redirect, url}), do: %{checkout_url: url}
  defp action_attrs({:instructions, map}), do: %{instructions: map}

  defp settle_invoice(%{status: :open} = invoice),
    do: Billing.mark_invoice_paid(invoice, authorize?: false)

  defp settle_invoice(_), do: :ok

  defp settle_subscription(%{status: status} = subscription)
       when status in [:incomplete, :trialing, :past_due],
       do: Billing.activate_subscription(subscription, authorize?: false)

  defp settle_subscription(%{status: :active} = subscription),
    do: Billing.renew_subscription(subscription, authorize?: false)

  defp settle_subscription(_), do: :ok

  defp schedule_verify(%Payment{id: id}) do
    %{payment_id: id}
    |> VerifyPayment.new(schedule_in: @verify_delay_seconds)
    |> Oban.insert()
  end

  defp confirmation_mode(module) do
    if function_exported?(module, :confirmation_mode, 0),
      do: module.confirmation_mode(),
      else: :verify
  end

  defp fetch_payment(reference) do
    case Billing.get_payment_by_reference(reference, authorize?: false) do
      {:ok, payment} -> {:ok, payment}
      {:error, _} -> {:error, :payment_not_found}
    end
  end
end
