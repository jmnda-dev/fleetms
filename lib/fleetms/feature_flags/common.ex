defmodule Fleetms.FeatureFlags.Common do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  def enable_reports do
    FunWithFlags.enable(@feature_flags.reports)
  end

  def enable_reports(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.reports, for_actor: actor)
  end

  def disable_reports do
    FunWithFlags.disable(@feature_flags.reports)
  end

  def disable_reports(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.reports, for_actor: actor)
  end

  def reports_enabled? do
    FunWithFlags.enabled?(@feature_flags.user_registration)
  end

  def reports_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.user_registration, for: actor)
  end
end
