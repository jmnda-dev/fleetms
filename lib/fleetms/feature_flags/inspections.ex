defmodule Fleetms.FeatureFlags.VehicleInspections do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  def enable_module do
    FunWithFlags.enable(@feature_flags.inspections_module)
  end

  def enable_module(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.inspections_module, for_actor: actor)
  end

  def disable_module do
    FunWithFlags.disable(@feature_flags.inspections_module)
  end

  def disable_module(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.inspections_module, for_actor: actor)
  end

  def module_enabled? do
    FunWithFlags.enabled?(@feature_flags.inspections_module)
  end

  def module_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.inspections_module, for: actor)
  end

  def enable_inspection_forms do
    FunWithFlags.enable(@feature_flags.inspection_forms)
  end

  def enable_inspection_forms(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.inspection_forms, for_actor: actor)
  end

  def enable_inspection_submissions do
    FunWithFlags.enable(@feature_flags.inspection_submissions)
  end

  def enable_inspection_submissions(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.inspection_submissions, for_actor: actor)
  end

  def inspection_forms_enabled? do
    FunWithFlags.enabled?(@feature_flags.inspection_forms)
  end

  def inspection_forms_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.inspection_forms, for: actor)
  end

  def inspection_submissions_enabled? do
    FunWithFlags.enabled?(@feature_flags.inspection_submissions)
  end

  def inspection_submissions_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.inspection_submissions, for: actor)
  end
end
