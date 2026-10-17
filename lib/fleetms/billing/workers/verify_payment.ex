defmodule Fleetms.Billing.Workers.VerifyPayment do
  @moduledoc """
  Re-verifies a payment with its provider, as a safety net for a missed browser
  return (DPO) or webhook. Enqueued when a payment starts processing; snoozes while
  the payment is still unresolved so a slow customer is caught, and gives up after a
  bounded number of attempts.
  """
  use Oban.Worker, queue: :billing, max_attempts: 5

  alias Fleetms.Billing
  alias Fleetms.Billing.Payments

  @snooze_seconds 120

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"payment_id" => payment_id}}) do
    case Billing.get_payment(payment_id, authorize?: false) do
      {:ok, %{status: status} = payment} when status in [:pending, :processing] ->
        case Payments.verify(payment) do
          {:ok, %{status: settled}} when settled in [:pending, :processing] ->
            {:snooze, @snooze_seconds}

          {:ok, _settled} ->
            :ok

          {:error, _} = error ->
            error
        end

      # Already settled, or the payment is gone — nothing to do.
      _ ->
        :ok
    end
  end
end
