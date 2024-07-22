defmodule Fleetms.Enums do
  @moduledoc """
  Defines enums for the Fleetms resources.
  """

  @doc false
  def vehicle_categories do
    [
      :"Heavy Equipment",
      :"Light Commercial",
      :"Passenger Cars",
      :"Commercial Trucks",
      :"Specialized Vehicles",
      :Motorcycles,
      :"Off Road Vehicles",
      :"Recreational Vehicles"
    ]
  end

  @doc false
  def vehicle_statuses do
    [
      :Active,
      :Maintenance,
      :"Out-of-Service"
    ]
  end

  def vehicle_assignment_statuses do
    [
      Past: "Past",
      "In-progress": "In-progress",
      Upcoming: "Upcoming"
    ]
  end

  def service_reminder_statuses do
    [
      :Upcoming,
      :"Due Soon",
      :Overdue
    ]
  end

  def general_reminder_statuses do
    [
      :Upcoming,
      :"Due Soon",
      :Overdue
    ]
  end

  @doc false
  def fuel_types do
    [
      :Gasoline,
      :Diesel,
      :Electric,
      :Hybrid,
      :Hydrogen
    ]
  end

  @doc false
  def fuel_delivery_types do
    [
      :"Direct Injection",
      :"Port Injection",
      :Carburetor,
      :"Multi-Point Injection"
    ]
  end

  @doc false
  def engine_config_types do
    [
      :Inline,
      :V,
      :W,
      :Boxer,
      :Flat,
      :Rotary
    ]
  end

  @doc false
  def valve_train_design_types do
    [
      :"Overhead Valve(OHV)",
      :"Overhead Camshaft(OHC)",
      :"Single Overhead Camshaft(SOHC)",
      :"Dual Overhead Camshaft(DOHC)"
    ]
  end

  @doc false
  def transmission_types do
    [
      :Automatic,
      :Manual,
      :CVT,
      :"Semi-Automatic"
    ]
  end

  @doc false
  def drive_types do
    [
      :"Front Wheel Drive(FWD)",
      :"Rear Wheel Drive(RWD)",
      :"All Wheel Drive(AWD)",
      :"Four Wheel Drive(4WD)"
    ]
  end

  @doc false
  def vehicle_types do
    [
      :Excavator,
      :Bulldozer,
      :Crane,
      :"Dump Truck",
      :Forklift,
      :"Pickup Truck",
      :Van,
      :Sedan,
      :SUV,
      :Hatchback,
      :Coupe,
      :Convertible,
      :Minivan,
      :Wagon,
      :Motorcycle,
      :ATV,
      :"Dirt Bike",
      :Motorhome,
      :Trailer,
      :Truck,
      :"Tractor Trailer",
      :Other
    ]
  end

  @doc false
  def aspiration_types do
    [
      :"Naturally Aspirated",
      :Turbocharged,
      :Supercharged,
      :"Twin Turbocharged",
      :"Twin Supercharged",
      :"Twin Turbocharged and Supercharged"
    ]
  end

  @doc false
  def brake_system_types do
    [
      :Hydraulic,
      :"Hydraulic with ABS",
      :Neumatic
    ]
  end

  @doc false
  def brake_types do
    [
      :"Ventilated Disc",
      :"Solid Disc",
      :"Composite Rotors",
      :"Carbon Ceramic Brakes",
      :"Drum Brakes",
      :"Electromagnetic Brakes",
      :"Integrated Brake System"
    ]
  end

  @doc false
  def cooling_system_types do
    [
      :Liquid,
      :Air
    ]
  end

  @doc false
  def steering_side do
    [:"Right Hand Drive", :"Left Hand Drive"]
  end

  @doc false
  def steering_type do
    [
      :"Steering rack and pinion",
      :"Recirculating Ball Steering",
      :"Electric Power Steering",
      :"Hydraulic Power Steering",
      :"Variable Assist Power Steering",
      :"Four-Wheel Steering"
    ]
  end

  @doc false
  def body_style do
    [
      :Sedan,
      :Coupe,
      :Convertible,
      :Hatchback,
      :Wagon,
      :SUV,
      :Van,
      :Truck,
      :Minivan,
      :Crossover,
      :"Pickup Truck",
      :Trailer,
      :Motorcycle,
      :Other
    ]
  end

  @doc false
  def issue_statuses do
    [
      :Open,
      :Closed,
      :Resolved
    ]
  end

  @doc false
  def issue_priority do
    [
      :Low,
      :Medium,
      :High,
      :None
    ]
  end

  @doc false
  def time_units do
    [
      :"Day(s)",
      :"Week(s)",
      :"Month(s)",
      :"Year(s)"
    ]
  end

  @doc false
  def resource_names do
    [
      :issue,
      :inspection,
      :work_order
    ]
  end

  @doc false
  def work_order_statuses do
    [
      :Open,
      :Pending,
      :Completed
    ]
  end

  @doc false
  def repair_categories do
    [
      :Preventative,
      :Corrective,
      :Emergency,
      :Scheduled
    ]
  end

  @doc false
  def fuel_tracking_fuel_types do
    [
      :Gasoline,
      :Diesel,
      :"Electric Charge",
      :Hydrogen
    ]
  end

  @doc false
  def fuel_tracking_payment_methods do
    [
      :Cash,
      :"Credit Card",
      :"Debit Card",
      :"Company Fuel Card",
      :"Mobile Payment",
      :"Fleet Card",
      :"Prepaid Card",
      :Check,
      :"Electronic Funds Transfer",
      :Other
    ]
  end

  @doc false
  def basic_user_roles do
    [
      :admin,
      :fleet_manager,
      :technician,
      :driver,
      :viewer
    ]
  end

  @doc false
  def user_statuses do
    [
      :Active,
      :Inactive
    ]
  end

  @doc false
  def genders do
    [
      :Male,
      :Female,
      :Other
    ]
  end

  def stock_quantity_statuses do
    [
      :"In Stock",
      :"Stock Low",
      :"Out of Stock",
      :"Not tracked"
    ]
  end
end
