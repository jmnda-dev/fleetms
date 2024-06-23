defmodule Fleetms.Vehicles.VehicleMake do
  @moduledoc """
  A VehicleMake resource
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
