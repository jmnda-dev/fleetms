defmodule Fleetms.Billing.Checkout do
  @moduledoc """
  The guarded entry point for an organization owner (or platform staff) to subscribe
  to a plan and pay, or to pay an existing open invoice.

  Billing writes are otherwise system-only (see the resource policies); this module
  authorizes the actor against the organization, then performs the writes as the
  system and hands off to `Fleetms.Billing.Payments` to initiate the collection.
  """
  require Ash.Query

  alias Fleetms.Billing
  alias Fleetms.Billing.Payments

  @doc """
  Subscribe `org` to a plan at `quantity` vehicles and start a payment with
  `provider`. Reuses an existing non-active subscription if there is one. Returns
  `{:ok, %{subscription:, invoice:, payment:}}` (the payment carries the checkout
  URL or pay-in instructions), or `{:error, reason}`.
  """
  def subscribe_and_pay(org, plan_id, quantity, provider, actor) do
    with :ok <- authorize(org.id, actor),
         {:ok, plan} <- Billing.get_plan(plan_id, authorize?: false),
         {:ok, subscription} <- ensure_subscription(org.id, plan, quantity, provider),
         {:ok, invoice} <- create_invoice(org.id, subscription, plan),
         {:ok, payment} <- create_payment(org.id, subscription, invoice, provider),
         {:ok, payment} <- Payments.initiate(payment) do
      {:ok, %{subscription: subscription, invoice: invoice, payment: payment}}
    end
  end

  @doc "Pay an existing open invoice with `provider`."
  def pay_invoice(invoice, provider, actor) do
    with :ok <- authorize(invoice.organization_id, actor),
         {:ok, payment} <-
           create_payment(invoice.organization_id, invoice.subscription_id, invoice, provider),
         {:ok, payment} <- Payments.initiate(payment) do
      {:ok, payment}
    end
  end

  @doc """
  Record an invoice as paid offline (bank transfer / mobile money received), by
  platform staff. Creates a `:manual` payment and runs the same cascade as an online
  payment — marking the invoice paid and activating/renewing the subscription.
  """
  def mark_invoice_paid_manually(invoice, %{is_super_admin: true}) do
    payment =
      Billing.create_payment!(
        %{
          organization_id: invoice.organization_id,
          invoice_id: invoice.id,
          subscription_id: invoice.subscription_id,
          provider: :manual,
          method: :manual,
          amount: invoice.amount_due
        },
        authorize?: false
      )

    Payments.apply_result(payment, %{status: :succeeded, method: :manual})
  end

  def mark_invoice_paid_manually(_invoice, _actor), do: {:error, :forbidden}

  # --- authorization ---

  defp authorize(_org_id, %{is_super_admin: true}), do: :ok

  defp authorize(org_id, %{id: user_id}) do
    owner? =
      Fleetms.Accounts.UserOrganization
      |> Ash.Query.filter(organization_id == ^org_id and user_id == ^user_id and owner? == true)
      |> Ash.exists?(authorize?: false)

    if owner?, do: :ok, else: {:error, :forbidden}
  end

  defp authorize(_org_id, _actor), do: {:error, :forbidden}

  # --- building the records ---

  defp ensure_subscription(org_id, plan, quantity, provider) do
    case latest_subscription(org_id) do
      %{status: status} = subscription
      when status in [:incomplete, :past_due, :canceled, :expired] ->
        Billing.update_subscription(subscription, %{quantity: quantity, provider: provider},
          authorize?: false
        )

      %{} = subscription ->
        # Already active/trialing — reuse as-is (a renewal pays the same plan).
        {:ok, subscription}

      nil ->
        Billing.subscribe(
          %{organization_id: org_id, plan_id: plan.id, quantity: quantity, provider: provider},
          authorize?: false
        )
    end
  end

  defp latest_subscription(org_id) do
    org_id
    |> Billing.list_organization_subscriptions!(authorize?: false)
    |> List.first()
  end

  defp create_invoice(org_id, subscription, plan) do
    amount = plan_amount(plan, subscription.quantity)

    Billing.create_invoice(
      %{
        organization_id: org_id,
        subscription_id: subscription.id,
        amount_due: amount,
        description: "#{plan.name} — #{subscription.quantity} vehicle(s)",
        line_items: [
          %{
            description: "#{plan.name} (#{plan.interval})",
            quantity: 1,
            unit_amount: amount,
            amount: amount
          }
        ]
      },
      authorize?: false
    )
    |> case do
      {:ok, invoice} -> Billing.issue_invoice(invoice, authorize?: false)
      error -> error
    end
  end

  defp create_payment(org_id, subscription, invoice, provider) do
    sub_id = if is_map(subscription), do: subscription.id, else: subscription

    Billing.create_payment(
      %{
        organization_id: org_id,
        invoice_id: invoice.id,
        subscription_id: sub_id,
        provider: provider,
        amount: invoice.amount_due
      },
      authorize?: false
    )
  end

  @doc "The amount for a plan at `quantity` vehicles: base plus any per-vehicle overage."
  def plan_amount(plan, quantity) do
    overage = max(quantity - (plan.included_vehicles || 0), 0)

    case plan.price_per_vehicle do
      %Money{} = per when overage > 0 -> Money.add!(plan.price, Money.mult!(per, overage))
      _ -> plan.price
    end
  end
end
