defmodule Fleetms.Enums do
  @moduledoc """
  Defines Enums to be used in the resources and liveviews.
  """

  @doc false
  def user_statuses do
    [
      :active,
      :inactive
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
  def vehicle_statuses do
    [
      :active,
      :under_maintenance,
      :out_of_service,
      :decommissioned
    ]
  end

  @doc false
  def vehicle_categories do
    [
      :heavy_equipment,
      :light_commercial,
      :passenger_cars,
      :commercial_trucks,
      :specialized_vehicles,
      :motorcycles,
      :off_road_vehicles,
      :recreational_vehicles
    ]
  end

  @doc false
  def vehicle_body_styles do
    [
      :sedan,
      :coupe,
      :convertible,
      :hatchback,
      :wagon,
      :SUV,
      :van,
      :truck,
      :minivan,
      :crossover,
      :pickup_truck,
      :trailer,
      :motorcycle,
      :other
    ]
  end

  @doc false
  def vehicle_types do
    [
      :pickup_truck,
      :van,
      :sedan,
      :SUV,
      :hatchback,
      :coupe,
      :convertible,
      :minivan,
      :wagon,
      :motorcycle,
      :ATV,
      :dirt_bike,
      :motorhome,
      :trailer,
      :truck,
      :tractor_trailer,
      :other
    ]
  end
end
