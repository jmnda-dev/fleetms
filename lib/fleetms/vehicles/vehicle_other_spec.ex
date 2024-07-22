defmodule Fleetms.Vehicles.VehicleOtherSpec do
  use Ash.Resource,
    domain: Fleetms.Vehicles,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # ========== DIMENSIONS ==========
    attribute :width, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :length, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :height, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :wheelbase, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    # ========== BRAKES ==========
    attribute :brake_system_type, :atom do
      public? true
      constraints one_of: Fleetms.Enums.brake_system_types()
    end

    attribute :front_brakes, :atom do
      public? true
      constraints one_of: Fleetms.Enums.brake_types()
    end

    attribute :rear_brakes, :atom do
      public? true
      constraints one_of: Fleetms.Enums.brake_types()
    end

    attribute :assisting_system, :atom do
      public? true
      constraints one_of: [:"ABS(Anti-lock braking system)", :Other]
    end

    # ========== TIRES ==========
    attribute :front_tire_spec, :string do
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :rear_tire_spec, :string do
      public? true
      constraints min_length: 0, max_length: 30
    end

    # =========== STEERING ===========
    attribute :steering_side, :atom do
      public? true
      constraints one_of: Fleetms.Enums.steering_side()
    end

    attribute :steering_type, :atom do
      public? true
      constraints one_of: Fleetms.Enums.steering_type()
    end

    # =========== SPACE, VOLUME AND WEIGHTS ===========
    attribute :gross_weight, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :fuel_tank_capacity, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :towing_capacity, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :net_weight, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :max_payload, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  relationships do
    belongs_to :vehicle, Fleetms.Vehicles.Vehicle, allow_nil?: false
  end

  identities do
    identity :unique_vehicle_id, [:vehicle_id]
  end

  postgres do
    table "vehicle_other_specs"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
