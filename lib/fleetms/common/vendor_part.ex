defmodule Fleetms.Common.VendorPart do
  use Ash.Resource,
    domain: Fleetms.Common,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :unit_cost, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 9_999_999_999
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :part, Fleetms.Inventory.Part do
      domain Fleetms.Inventory
      allow_nil? false
      destination_attribute :id
      primary_key? true
    end

    belongs_to :vendor, Fleetms.Common.Vendor do
      domain Fleetms.Common
      allow_nil? false
      primary_key? true
      destination_attribute :id
    end
  end

  postgres do
    table "vendors_parts"
    repo Fleetms.Repo

    references do
      reference :part, on_delete: :delete
      reference :vendor, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  multitenancy do
    strategy :context
  end
end
