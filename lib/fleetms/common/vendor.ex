defmodule Fleetms.Common.Vendor do
  use Ash.Resource,
    domain: Fleetms.Common,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      allow_nil? true
      constraints min_length: 1, max_length: 1000
    end

    attribute :phone, :string do
      public? true
      allow_nil? true
      constraints min_length: 10, max_length: 15
    end

    attribute :email, :string do
      public? true
      allow_nil? true
      constraints min_length: 5, max_length: 65
    end

    attribute :address, :string do
      public? true
      allow_nil? true
      constraints min_length: 1, max_length: 300
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :vendor_parts, Fleetms.Common.VendorPart
  end

  postgres do
    table "vendors"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  identities do
    identity :unique_vendor, [:name]
  end

  multitenancy do
    strategy :context
  end
end
