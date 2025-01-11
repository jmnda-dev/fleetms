defmodule Fleetms.VehicleInspection.Form.InputChoice do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 50
    end

    attribute :fail_if_selected, :boolean do
      allow_nil? false
      public? true
      default false
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  identities do
    identity :unique_label, [:label]
  end
end
