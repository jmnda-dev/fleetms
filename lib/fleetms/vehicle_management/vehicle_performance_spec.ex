defmodule Fleetms.VehicleManagement.VehiclePerformanceSpec do
  use Ash.Resource,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :fuel_consumption_urban, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      description "Consumption in Liters per 100km"
    end

    attribute :fuel_consumption_extra_urban, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      description "Consumption in Liters per 100km"
    end

    attribute :fuel_consumption_combined, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      description "Consumption in Liters per 100km"
    end

    attribute :co2_emission, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      description "CO2 Emissions in g/km"
    end

    attribute :acceleration_0_to_100, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      description "Acceleration 0 - 100km in seconds"
    end

    attribute :maximum_speed, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      description "Max speed in km/h"
    end

    attribute :emission_standard, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle, allow_nil?: false
  end

  identities do
    identity :unique_vehicle_id, [:vehicle_id]
  end

  postgres do
    table "vehicle_performance_specs"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
