defmodule Fleetms.Billing.BillingInterval do
  @moduledoc "How often a plan bills: monthly or annually."
  use Ash.Type.Enum, values: [:month, :year]
end
