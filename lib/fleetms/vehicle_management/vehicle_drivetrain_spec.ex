defmodule Fleetms.VehicleManagement.VehicleDrivetrainSpec do
  use Ash.Resource,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # ========== TRANSMISSION SPECIFICATIONS ==========
    attribute :manufacturer, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The manufacturer of the vehicle transmission."
    end

    attribute :model, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The model of the vehicle transmission."
    end

    attribute :serial_number, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The serial number of the vehicle transmission."
    end

    attribute :transmission_type, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.transmission_types()
    end

    attribute :number_of_gears, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 100
      description "The number of gears of the vehicle transmission."
    end

    attribute :transmission_oil_capacity, :decimal do
      allow_nil? true
      public? true
      constraints min: 0.0, max: 200.0
      description "The oil capacity of the vehicle transmission in liters."
    end

    attribute :transmission_oil_specification, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The oil specification of the vehicle transmission. For example 'DEXRON VI'."
    end

    # ========== OTHER DRIVETRAIN SPECS ==========
    attribute :drive_type, :atom do
      constraints one_of: Fleetms.Enums.drive_types()
      public? true
    end

    attribute :axles, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 99999
    end

    attribute :axle_configuration, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 99999
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle, allow_nil?: false
  end

  postgres do
    table "vehicle_drivetrain_specs"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  identities do
    identity :unique_vehicle_id, [:vehicle_id]
  end

  multitenancy do
    strategy :context
  end
end
