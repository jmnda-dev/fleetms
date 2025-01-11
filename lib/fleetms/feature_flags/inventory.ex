defmodule Fleetms.FeatureFlags.Inventory do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  def enable_module do
    FunWithFlags.enable(@feature_flags.inventory_module)
  end

  def enable_module(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.inventory_module, for_actor: actor)
  end

  def disable_module do
    FunWithFlags.disable(@feature_flags.inventory_module)
  end

  def disable_module(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.inventory_module, for_actor: actor)
  end

  def module_enabled? do
    FunWithFlags.enabled?(@feature_flags.inventory_module)
  end

  def module_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.inventory_module, for: actor)
  end

  def enable_parts do
    FunWithFlags.enable(@feature_flags.parts)
  end

  def enable_parts(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.parts, for_actor: actor)
  end

  def disable_parts do
    FunWithFlags.disable(@feature_flags.parts)
  end

  def disable_parts(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.parts, for_actor: actor)
  end

  def parts_enabled? do
    FunWithFlags.enabled?(@feature_flags.parts)
  end

  def parts_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.parts, for: actor)
  end

  def enable_inventory_location do
    FunWithFlags.enable(@feature_flags.inventory_location)
  end

  def enable_inventory_location(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.inventory_location, for_actor: actor)
  end

  def disable_inventory_location do
    FunWithFlags.disable(@feature_flags.inventory_location)
  end

  def disable_inventory_location(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.inventory_location, for_actor: actor)
  end

  def inventory_location_enabled? do
    FunWithFlags.enabled?(@feature_flags.inventory_location)
  end

  def inventory_location_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.inventory_location, for: actor)
  end
end
