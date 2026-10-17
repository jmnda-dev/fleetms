defmodule Fleetms.VehicleManagement.VehicleSpec do
  @moduledoc """
  Detailed mechanical specifications for a vehicle — engine, drivetrain,
  performance, dimensions, brakes, tyres, steering and weights — modelled on the
  way auto-data.net presents them.

  The legacy app split these across four tables; here they're one `has_one` per
  vehicle, grouped only by section comments. Every field is optional: a vehicle
  may have as much or as little spec data as is known.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1, has_any_permission: 1]

  alias Fleetms.VehicleManagement

  @writable_attrs [
    # Engine
    :engine_manufacturer,
    :engine_model,
    :engine_serial_number,
    :aspiration,
    :displacement,
    :cylinders,
    :cylinder_bore,
    :valves_per_cylinder,
    :compression_ratio,
    :piston_stroke,
    :power,
    :torque,
    :fuel_type,
    :fuel_delivery_type,
    :engine_configuration,
    :valve_train_design,
    :cooling_type,
    :oil_capacity,
    :oil_specification,
    # Drivetrain
    :transmission_manufacturer,
    :transmission_model,
    :transmission_serial_number,
    :transmission_type,
    :number_of_gears,
    :transmission_oil_capacity,
    :transmission_oil_specification,
    :drive_type,
    :axles,
    :axle_configuration,
    # Performance
    :fuel_consumption_urban,
    :fuel_consumption_extra_urban,
    :fuel_consumption_combined,
    :co2_emission,
    :acceleration_0_to_100,
    :maximum_speed,
    :emission_standard,
    # Dimensions
    :length,
    :width,
    :height,
    :wheelbase,
    # Brakes
    :brake_system_type,
    :front_brakes,
    :rear_brakes,
    :assisting_system,
    # Tyres
    :front_tire_spec,
    :rear_tire_spec,
    # Steering
    :steering_side,
    :steering_type,
    # Weights & volume
    :gross_weight,
    :net_weight,
    :max_payload,
    :towing_capacity,
    :fuel_tank_capacity
  ]

  postgres do
    table "vehicle_specs"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    create :create do
      primary? true
      accept [:vehicle_id | @writable_attrs]
    end

    update :update do
      primary? true
      accept @writable_attrs
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_vehicles)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if has_any_permission([:create_vehicle, :update_vehicle])
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    # --- Engine ---
    attribute :engine_manufacturer, :string, public?: true, constraints: [max_length: 100]
    attribute :engine_model, :string, public?: true, constraints: [max_length: 100]
    attribute :engine_serial_number, :string, public?: true, constraints: [max_length: 100]
    attribute :aspiration, VehicleManagement.Aspiration, public?: true

    attribute :displacement, :decimal,
      public?: true,
      constraints: [min: 0, max: 100],
      description: "Engine displacement in litres."

    attribute :cylinders, :integer, public?: true, constraints: [min: 0, max: 100]

    attribute :cylinder_bore, :decimal,
      public?: true,
      constraints: [min: 0, max: 1000],
      description: "Cylinder bore in millimetres."

    attribute :valves_per_cylinder, :integer, public?: true, constraints: [min: 0, max: 100]
    attribute :compression_ratio, :string, public?: true, constraints: [max_length: 100]

    attribute :piston_stroke, :decimal,
      public?: true,
      constraints: [min: 0, max: 1000],
      description: "Piston stroke in millimetres."

    attribute :power, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999],
      description: "Engine power in kilowatts."

    attribute :torque, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999],
      description: "Engine torque in newton-metres."

    attribute :fuel_type, VehicleManagement.FuelType, public?: true
    attribute :fuel_delivery_type, VehicleManagement.FuelDeliveryType, public?: true
    attribute :engine_configuration, VehicleManagement.EngineConfiguration, public?: true
    attribute :valve_train_design, VehicleManagement.ValveTrainDesign, public?: true
    attribute :cooling_type, VehicleManagement.CoolingType, public?: true

    attribute :oil_capacity, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999],
      description: "Engine oil capacity in litres."

    attribute :oil_specification, :string,
      public?: true,
      constraints: [max_length: 100],
      description: "e.g. 5W-30."

    # --- Drivetrain ---
    attribute :transmission_manufacturer, :string, public?: true, constraints: [max_length: 100]
    attribute :transmission_model, :string, public?: true, constraints: [max_length: 100]
    attribute :transmission_serial_number, :string, public?: true, constraints: [max_length: 100]
    attribute :transmission_type, VehicleManagement.TransmissionType, public?: true
    attribute :number_of_gears, :integer, public?: true, constraints: [min: 0, max: 100]

    attribute :transmission_oil_capacity, :decimal,
      public?: true,
      constraints: [min: 0, max: 200],
      description: "Transmission oil capacity in litres."

    attribute :transmission_oil_specification, :string,
      public?: true,
      constraints: [max_length: 100]

    attribute :drive_type, VehicleManagement.DriveType, public?: true
    attribute :axles, :integer, public?: true, constraints: [min: 0, max: 99_999]
    attribute :axle_configuration, :string, public?: true, constraints: [max_length: 100]

    # --- Performance ---
    attribute :fuel_consumption_urban, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999_999],
      description: "Urban consumption, L/100km."

    attribute :fuel_consumption_extra_urban, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999_999],
      description: "Extra-urban consumption, L/100km."

    attribute :fuel_consumption_combined, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999_999],
      description: "Combined consumption, L/100km."

    attribute :co2_emission, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999_999],
      description: "CO2 emissions in g/km."

    attribute :acceleration_0_to_100, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999_999],
      description: "0–100 km/h in seconds."

    attribute :maximum_speed, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999_999],
      description: "Top speed in km/h."

    attribute :emission_standard, :string, public?: true, constraints: [max_length: 100]

    # --- Dimensions (mm) ---
    attribute :length, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]
    attribute :width, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]
    attribute :height, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]
    attribute :wheelbase, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]

    # --- Brakes ---
    attribute :brake_system_type, VehicleManagement.BrakeSystemType, public?: true
    attribute :front_brakes, VehicleManagement.BrakeType, public?: true
    attribute :rear_brakes, VehicleManagement.BrakeType, public?: true
    attribute :assisting_system, VehicleManagement.BrakeAssist, public?: true

    # --- Tyres ---
    attribute :front_tire_spec, :string, public?: true, constraints: [max_length: 30]
    attribute :rear_tire_spec, :string, public?: true, constraints: [max_length: 30]

    # --- Steering ---
    attribute :steering_side, VehicleManagement.SteeringSide, public?: true
    attribute :steering_type, VehicleManagement.SteeringType, public?: true

    # --- Weights (kg) & volume (L) ---
    attribute :gross_weight, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]
    attribute :net_weight, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]
    attribute :max_payload, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]
    attribute :towing_capacity, :decimal, public?: true, constraints: [min: 0, max: 999_999_999]

    attribute :fuel_tank_capacity, :decimal,
      public?: true,
      constraints: [min: 0, max: 999_999_999]

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
    end
  end
end
