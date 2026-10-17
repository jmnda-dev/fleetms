defmodule Fleetms.Billing.InvoiceLineItem do
  @moduledoc "A single line on an invoice. Stored embedded in the invoice's JSON."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :description, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 500
    end

    attribute :quantity, :integer do
      allow_nil? false
      public? true
      default 1
      constraints min: 1
    end

    attribute :unit_amount, AshMoney.Types.Money do
      allow_nil? false
      public? true
    end

    attribute :amount, AshMoney.Types.Money do
      allow_nil? false
      public? true
      description "Line total (quantity × unit_amount), computed by the caller."
    end
  end
end
