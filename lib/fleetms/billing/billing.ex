defmodule Fleetms.Billing do
  @moduledoc """
  Platform billing: the plans the platform offers, an organization's subscription
  and its entitlement, the invoices it's issued, and the payments collected against
  them.

  These are **platform-level** records (an org pays the platform), so they live in
  the public schema and are keyed by `organization_id` — they are not tenant data.
  Provider integration (DPO, Lenco) is layered on top of `Payment` separately; this
  domain is the data model and lifecycle only.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix]

  resources do
    resource Fleetms.Billing.Plan do
      define :list_plans, action: :read
      define :list_active_plans, action: :list_active
      define :get_plan, action: :get_by_id, args: [:id]
      define :create_plan, action: :create
      define :update_plan, action: :update
      define :delete_plan, action: :destroy
    end

    resource Fleetms.Billing.Subscription do
      define :get_subscription, action: :get_by_id, args: [:id]

      define :list_organization_subscriptions,
        action: :list_for_organization,
        args: [:organization_id]

      define :list_subscriptions_past_period, action: :list_past_period, args: [:as_of]
      define :list_subscriptions_past_due_before, action: :list_past_due_before, args: [:cutoff]

      define :subscribe, action: :subscribe
      define :update_subscription, action: :update
      define :activate_subscription, action: :activate
      define :renew_subscription, action: :renew
      define :mark_subscription_past_due, action: :mark_past_due
      define :cancel_subscription, action: :cancel
      define :expire_subscription, action: :expire
    end

    resource Fleetms.Billing.Invoice do
      define :get_invoice, action: :get_by_id, args: [:id]
      define :list_organization_invoices, action: :list_for_organization, args: [:organization_id]
      define :create_invoice, action: :create
      define :issue_invoice, action: :open
      define :mark_invoice_paid, action: :mark_paid
      define :void_invoice, action: :void
      define :mark_invoice_uncollectible, action: :mark_uncollectible
    end

    resource Fleetms.Billing.Payment do
      define :get_payment, action: :get_by_id, args: [:id]
      define :get_payment_by_reference, action: :get_by_reference, args: [:reference]
      define :list_organization_payments, action: :list_for_organization, args: [:organization_id]
      define :create_payment, action: :create
      define :start_payment_processing, action: :start_processing
      define :succeed_payment, action: :succeed
      define :fail_payment, action: :fail
      define :cancel_payment, action: :cancel
      define :expire_payment, action: :expire
    end
  end
end
