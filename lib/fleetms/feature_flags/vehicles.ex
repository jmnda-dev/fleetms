defmodule Fleetms.FeatureFlags.VehicleManagement do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  def enable_module do
    FunWithFlags.enable(@feature_flags.vehicles_module)
  end

  def enable_module(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.vehicles_module, for_actor: actor)
  end

  def disable_module do
    FunWithFlags.disable(@feature_flags.vehicles_module)
  end

  def disable_module(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.vehicles_module, for_actor: actor)
  end

  def module_enabled? do
    FunWithFlags.enabled?(@feature_flags.vehicles_module)
  end

  def module_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.vehicles_module, for: actor)
  end

  def enable_vehicles do
    FunWithFlags.enable(@feature_flags.vehicles)
  end

  def enable_vehicles(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.vehicles, for_actor: actor)
  end

  def enable_vehicle_assignments do
    FunWithFlags.enable(@feature_flags.vehicle_assignments)
  end

  def enable_vehicle_assignments(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.vehicle_assignments, for_actor: actor)
  end

  def enable_vehicle_reminders do
    FunWithFlags.enable(@feature_flags.vehicle_reminders)
  end

  def enable_vehicle_reminders(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.vehicle_reminders, for_actor: actor)
  end

  def vehicles_enabled? do
    FunWithFlags.enabled?(@feature_flags.vehicles)
  end

  def vehicles_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.vehicles, for: actor)
  end

  def vehicle_assignments_enabled? do
    FunWithFlags.enabled?(@feature_flags.vehicle_assignments)
  end

  def vehicle_assignments_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.vehicle_assignments, for: actor)
  end

  def vehicle_reminders_enabled? do
    FunWithFlags.enabled?(@feature_flags.vehicle_reminders)
  end

  def vehicle_reminders_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.vehicle_reminders, for: actor)
  end
end
