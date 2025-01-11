defmodule Fleetms.FeatureFlags.FuelManagement do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  # Enable Fuel Tracking Module
  def enable_module do
    FunWithFlags.enable(@feature_flags.fuel_tracking_module)
  end

  def enable_module(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.fuel_tracking_module, for_actor: actor)
  end

  # Disable Fuel Tracking Module
  def disable_module do
    FunWithFlags.disable(@feature_flags.fuel_tracking_module)
  end

  def disable_module(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.fuel_tracking_module, for_actor: actor)
  end

  # Check if Fuel Tracking Module is Enabled
  def module_enabled? do
    FunWithFlags.enabled?(@feature_flags.fuel_tracking_module)
  end

  def module_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.fuel_tracking_module, for: actor)
  end

  # Fuel Histories Feature
  def enable_fuel_histories do
    FunWithFlags.enable(@feature_flags.fuel_histories)
  end

  def enable_fuel_histories(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.fuel_histories, for_actor: actor)
  end

  def disable_fuel_histories do
    FunWithFlags.disable(@feature_flags.fuel_histories)
  end

  def disable_fuel_histories(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.fuel_histories, for_actor: actor)
  end

  def fuel_histories_enabled? do
    FunWithFlags.enabled?(@feature_flags.fuel_histories)
  end

  def fuel_histories_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.fuel_histories, for: actor)
  end
end
