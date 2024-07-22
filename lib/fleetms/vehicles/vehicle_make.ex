defmodule Fleetms.Vehicles.VehicleMake do
  use Ash.Resource,
    domain: Fleetms.Vehicles,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :vehicle_models, Fleetms.Vehicles.VehicleModel
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :create do
      primary? true
      accept :*
      upsert? true
      upsert_fields [:name]
      upsert_identity :unique_name
    end

    read :get_all
  end

  code_interface do


    define :get_all, action: :get_all
  end

  identities do
    identity :unique_name, [:name]
  end

  postgres do
    table "vehicle_makes"
    repo Fleetms.Repo
  end

  multitenancy do
    strategy :context
  end
end
