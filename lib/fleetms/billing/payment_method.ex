defmodule Fleetms.Billing.PaymentMethod do
  @moduledoc "How the customer paid: mobile money, card, bank transfer, or offline (manual)."
  use Ash.Type.Enum, values: [:mobile_money, :card, :bank_transfer, :manual]
end
