defmodule Fleetms.Vehicles.VehicleModel do
  @moduledoc """
  A VehicleModel resource
  """

  use Ash.Resource,
    domain: Fleetms.Vehicles,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :details, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 500
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  postgres do
    table "vehicle_models"
    repo Fleetms.Repo

    references do
      reference :vehicle_make, on_delete: :delete
    end
  end

  relationships do
    belongs_to :vehicle_make, Fleetms.Vehicles.VehicleMake do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :details]

      upsert? true
      upsert_fields [:name]
      upsert_identity :unique_name

      argument :vehicle_make, :map, allow_nil?: false

      change manage_relationship(:vehicle_make,
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               identity_priority: [:unique_name],
               use_identities: [:unique_name]
             )
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :details]

      argument :vehicle_make, :map, allow_nil?: false

      change manage_relationship(:vehicle_make,
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               identity_priority: [:unique_name],
               use_identities: [:unique_name]
             )
    end
  end

  identities do
    identity :unique_name, [:name]
  end

  multitenancy do
    strategy :context
  end
end
