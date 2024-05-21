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
    defaults [:read, :destroy, create: :*, update: :*]
  end

  multitenancy do
    strategy :context
  end
end
