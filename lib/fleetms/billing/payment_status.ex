defmodule Fleetms.Billing.PaymentStatus do
  @moduledoc """
  The lifecycle of a single collection attempt.

    * `:pending`    — created; the customer has not paid yet.
    * `:processing` — handed off to the provider (redirected to checkout, or a
                      pay-in is awaited).
    * `:succeeded`  — funds confirmed.
    * `:failed`     — the provider reported a failure.
    * `:canceled`   — abandoned by the customer or staff.
    * `:expired`    — the attempt timed out without payment.
  """
  use Ash.Type.Enum,
    values: [:pending, :processing, :succeeded, :failed, :canceled, :expired]
end
