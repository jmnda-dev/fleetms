defmodule Fleetms.Vehicles.VehicleModel do
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

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      upsert? true
      upsert_fields [:name]
      upsert_identity :unique_name

      argument :vehicle_make, :map, allow_nil?: false

      change manage_relationship(:vehicle_make,
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               on_missing: :destroy,
               identity_priority: [:unique_name],
               use_identities: [:unique_name]
             )
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :vehicle_make, :map, allow_nil?: false

      change manage_relationship(:vehicle_make,
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               on_missing: :destroy,
               identity_priority: [:unique_name],
               use_identities: [:unique_name]
             )
    end

    read :list_by_vehicle_make do
      argument :vehicle_make, :string, allow_nil?: false

      prepare build(load: [:vehicle_make])
      filter expr(vehicle_make.name == ^arg(:vehicle_make))
    end
  end

  code_interface do
    define :list_by_vehicle_make, action: :list_by_vehicle_make, args: [:vehicle_make]
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    belongs_to :vehicle_make, Fleetms.Vehicles.VehicleMake do
      allow_nil? false
    end
  end

  postgres do
    table "vehicle_models"
    repo Fleetms.Repo
  end

  multitenancy do
    strategy :context
  end
end
