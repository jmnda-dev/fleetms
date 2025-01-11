defmodule Fleetms.VehicleMaintenance.WorkOrderDocument do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    uuid_primary_key :id

    attribute :url, :string do
      allow_nil? false
    end

    attribute :mime_type, :string do
      allow_nil? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      allow_nil? true
      constraints min_length: 1, max_length: 1000
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

end
