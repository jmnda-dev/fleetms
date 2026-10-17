defmodule Fleetms.Billing.PaymentProviderType do
  @moduledoc """
  Which gateway collects a payment. `:manual` covers offline settlement (bank
  transfer / mobile money paid directly, then marked paid by staff) — the
  no-integration path the business is expected to launch on.
  """
  use Ash.Type.Enum, values: [:dpo, :lenco, :manual]
end
