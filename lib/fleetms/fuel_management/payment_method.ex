defmodule Fleetms.FuelManagement.PaymentMethod do
  @moduledoc "How a refuel was paid for."
  use Ash.Type.Enum,
    values: [:cash, :credit_card, :debit_card, :fuel_card, :mobile_payment, :other]
end
