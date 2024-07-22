defmodule Fleetms.Vehicles.VehicleGroup do
  @moduledoc """
  Defines the vehicle group resource.
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
      description "The name of the vehicle group."
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 500
      description "A description of the vehicle group."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :vehicles, Fleetms.Vehicles.Vehicle do
      description "The vehicles in this vehicle group."
    end
  end

  postgres do
    table "vehicle_groups"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  identities do
    identity :unique_name, [:name]
  end

  multitenancy do
    strategy :context
  end
end
