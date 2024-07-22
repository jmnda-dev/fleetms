defmodule Fleetms.Inventory.PartDocument do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
      description "The URL of the Part document."
    end

    attribute :caption, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
      description "The caption of the Part document."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

end
