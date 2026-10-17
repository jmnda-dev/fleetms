defmodule Fleetms.Billing.Lifecycle do
  @moduledoc """
  Time-driven subscription transitions, run periodically by
  `Fleetms.Billing.Workers.SweepSubscriptions`:

    * an **active** subscription whose paid period has ended moves to **past_due**
      (dunning) and gets an open **renewal invoice** so the owner has something to
      pay;
    * a **past_due** subscription still unpaid after the grace window **expires**.

  All writes run as the system (`authorize?: false`) — there is no user actor.
  """
  alias Fleetms.Billing
  alias Fleetms.Billing.Checkout

  @doc "Run one sweep. `now` is injectable for testing."
  def run(now \\ DateTime.utc_now()) do
    lapse_active(now)
    expire_past_due(now)
    :ok
  end

  defp lapse_active(now) do
    now
    |> Billing.list_subscriptions_past_period!(authorize?: false, load: [:plan])
    |> Enum.each(fn subscription ->
      {:ok, subscription} = Billing.mark_subscription_past_due(subscription, authorize?: false)
      ensure_renewal_invoice(subscription)
    end)
  end

  defp expire_past_due(now) do
    cutoff = DateTime.add(now, -grace_days() * 86_400, :second)

    cutoff
    |> Billing.list_subscriptions_past_due_before!(authorize?: false)
    |> Enum.each(&Billing.expire_subscription(&1, authorize?: false))
  end

  # Issue one open renewal invoice per lapse; don't pile up duplicates if the sweep
  # runs again before payment.
  defp ensure_renewal_invoice(subscription) do
    already_open? =
      subscription.organization_id
      |> Billing.list_organization_invoices!(authorize?: false)
      |> Enum.any?(&(&1.subscription_id == subscription.id and &1.status == :open))

    unless already_open? do
      amount = Checkout.plan_amount(subscription.plan, subscription.quantity)

      Billing.create_invoice!(
        %{
          organization_id: subscription.organization_id,
          subscription_id: subscription.id,
          amount_due: amount,
          description: "Renewal — #{subscription.plan.name}"
        },
        authorize?: false
      )
      |> Billing.issue_invoice!(authorize?: false)
    end
  end

  defp grace_days, do: Application.get_env(:fleetms, Fleetms.Billing, [])[:grace_days] || 7
end
