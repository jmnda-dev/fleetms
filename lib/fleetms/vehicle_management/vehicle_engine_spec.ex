defmodule Fleetms.VehicleManagement.VehicleEngineSpec do
  @moduledoc """
  Defines the vehicle engine information resource, as an embedded resource.
  """
  use Ash.Resource,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :manufacturer, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The manufacturer of the vehicle engine."
    end

    attribute :model, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The model of the vehicle engine."
    end

    attribute :serial_number, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The serial number of the vehicle engine."
    end

    attribute :aspiration, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.aspiration_types()

      description "The aspiration type of the vehicle engine. Can be either 'Naturally Aspirated', 'Turbocharged', 'Supercharged', 'Twin Turbocharged', 'Twin Supercharged', 'Other'."
    end

    attribute :displacement, :decimal do
      allow_nil? true
      public? true
      constraints min: 0.0, max: 100.0
      description "The displacement of the vehicle engine in liters."
    end

    attribute :cylinders, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 100
      description "The number of cylinders of the vehicle engine."
    end

    attribute :cylinder_bore, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 1000
      description "The Cylinder bore measurement in milimeters."
    end

    attribute :valves_per_cylinder, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 100
    end

    attribute :compression_ratio, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :piston_stroke, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 1000
      description "The Piston Stroke in milimeters"
    end

    attribute :power, :decimal do
      allow_nil? true
      public? true
      constraints min: 0.0, max: 999_999.0
      description "The power of the vehicle engine in kilowatts."
    end

    attribute :torque, :decimal do
      allow_nil? true
      public? true
      constraints min: 0.0, max: 999_999.0
      description "The torque of the vehicle engine in newton meters."
    end

    attribute :fuel_type, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.fuel_types()

      description "The fuel type of the vehicle engine. Can be either 'Gasoline', 'Diesel', 'Electric', 'Hybrid', 'Other'."
    end

    attribute :fuel_delivery_type, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.fuel_delivery_types()

      description "The fuel delivery type of the vehicle engine. Can be either 'Carburetor', 'Fuel Injection', 'Direct Injection', 'Other'."
    end

    attribute :config_type, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.engine_config_types()

      description "The engine configuration type of the vehicle engine. Can be either 'Inline', 'V', 'W', 'Boxer', 'Other'."
    end

    attribute :valve_train_design, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.valve_train_design_types()
      description "The valve train design or Cam shaft layout of the vehicle engine."
    end

    attribute :cooling_type, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.cooling_system_types()
      description "The cooling system type of the vehicle engine."
    end

    attribute :oil_capacity, :decimal do
      allow_nil? true
      public? true
      constraints min: 0.0, max: 999_999.0
      description "The oil capacity of the vehicle engine in liters."
    end

    attribute :oil_specification, :string do
      allow_nil? true
      public? true

      constraints min_length: 1,
                  max_length: 100

      description "The oil specification of the vehicle engine. For example, '5W-30'."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle, allow_nil?: false
  end

  postgres do
    table "vehicle_engine_specs"
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
