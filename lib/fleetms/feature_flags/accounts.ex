defmodule Fleetms.FeatureFlags.Accounts do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  def enable_user_registration do
    FunWithFlags.enable(@feature_flags.user_registration)
  end

  def enable_user_registration(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.user_registration, for_actor: actor)
  end

  def enable_user_management do
    FunWithFlags.enable(@feature_flags.user_management)
  end

  def enable_user_management(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.user_management, for_actor: actor)
  end

  def disable_user_registration do
    FunWithFlags.disable(@feature_flags.user_registration)
  end

  def disable_user_registration(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.user_registration, for_actor: actor)
  end

  def disable_user_management do
    FunWithFlags.enable(@feature_flags.user_management)
  end

  def disable_user_management(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.user_management, for_actor: actor)
  end

  def user_registration_enabled? do
    FunWithFlags.enabled?(@feature_flags.user_registration)
  end

  def user_registration_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.user_registration, for: actor)
  end

  def user_management_enabled? do
    FunWithFlags.enabled?(@feature_flags.user_management)
  end

  def user_management_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.user_management, for: actor)
  end
end
