defmodule Fleetms.Billing.InvoiceStatus do
  @moduledoc """
  The lifecycle of an invoice: `:draft` → `:open` → `:paid`, with `:void` and
  `:uncollectible` as terminal off-ramps.
  """
  use Ash.Type.Enum, values: [:draft, :open, :paid, :void, :uncollectible]
end
