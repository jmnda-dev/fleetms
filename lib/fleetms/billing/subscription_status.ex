defmodule Fleetms.Billing.SubscriptionStatus do
  @moduledoc """
  The lifecycle of an organization's subscription.

    * `:incomplete` — created, awaiting the first successful payment.
    * `:trialing`   — in a free trial; entitled to use the product.
    * `:active`     — paid and current; entitled.
    * `:past_due`   — a renewal payment failed; usually kept entitled during a grace
                      period before expiry.
    * `:canceled`   — ended by the customer or staff.
    * `:expired`    — lapsed (grace period elapsed without payment).
  """
  use Ash.Type.Enum,
    values: [:incomplete, :trialing, :active, :past_due, :canceled, :expired]
end
