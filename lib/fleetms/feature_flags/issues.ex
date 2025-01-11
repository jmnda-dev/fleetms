defmodule Fleetms.FeatureFlags.VehicleIssues do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  def enable_module do
    FunWithFlags.enable(@feature_flags.issues_module)
  end

  def enable_module(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.issues_module, for_actor: actor)
  end

  def disable_module do
    FunWithFlags.disable(@feature_flags.issues_module)
  end

  def disable_module(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.issues_module, for_actor: actor)
  end

  def module_enabled? do
    FunWithFlags.enabled?(@feature_flags.issues_module)
  end

  def module_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.issues_module, for: actor)
  end

  def enable_issues do
    FunWithFlags.enable(@feature_flags.issues)
  end

  def enable_issues(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.issues, for_actor: actor)
  end

  def issues_enabled? do
    FunWithFlags.enabled?(@feature_flags.issues)
  end

  def issues_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.issues, for: actor)
  end
end
