defmodule Fleetms.FeatureFlags.VehicleMaintenance do
  alias Fleetms.FeatureFlags
  alias Fleetms.Accounts.Organization
  @feature_flags FeatureFlags.get_flags()

  def enable_module do
    FunWithFlags.enable(@feature_flags.service_module)
  end

  def enable_module(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.service_module, for_actor: actor)
  end

  def disable_module do
    FunWithFlags.disable(@feature_flags.service_module)
  end

  def disable_module(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.service_module, for_actor: actor)
  end

  def module_enabled? do
    FunWithFlags.enabled?(@feature_flags.service_module)
  end

  def module_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.service_module, for: actor)
  end

  def enable_service_tasks do
    FunWithFlags.enable(@feature_flags.service_tasks)
  end

  def enable_service_tasks(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.service_tasks, for_actor: actor)
  end

  def disable_service_tasks do
    FunWithFlags.disable(@feature_flags.service_tasks)
  end

  def disable_service_tasks(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.service_tasks, for_actor: actor)
  end

  def service_tasks_enabled? do
    FunWithFlags.enabled?(@feature_flags.service_tasks)
  end

  def service_tasks_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.service_tasks, for: actor)
  end

  def enable_service_groups do
    FunWithFlags.enable(@feature_flags.service_groups)
  end

  def enable_service_groups(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.service_groups, for_actor: actor)
  end

  def disable_service_groups do
    FunWithFlags.disable(@feature_flags.service_groups)
  end

  def disable_service_groups(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.service_groups, for_actor: actor)
  end

  def service_groups_enabled? do
    FunWithFlags.enabled?(@feature_flags.service_groups)
  end

  def service_groups_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.service_groups, for: actor)
  end

  def enable_service_reminders do
    FunWithFlags.enable(@feature_flags.service_reminders)
  end

  def enable_service_reminders(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.service_reminders, for_actor: actor)
  end

  def disable_service_reminders do
    FunWithFlags.disable(@feature_flags.service_reminders)
  end

  def disable_service_reminders(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.service_reminders, for_actor: actor)
  end

  def service_reminders_enabled? do
    FunWithFlags.enabled?(@feature_flags.service_reminders)
  end

  def service_reminders_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.service_reminders, for: actor)
  end

  def enable_work_order do
    FunWithFlags.enable(@feature_flags.work_orders)
  end

  def enable_work_order(%Organization{} = actor) do
    FunWithFlags.enable(@feature_flags.work_orders, for_actor: actor)
  end

  def disable_work_order do
    FunWithFlags.disable(@feature_flags.work_orders)
  end

  def disable_work_order(%Organization{} = actor) do
    FunWithFlags.disable(@feature_flags.work_orders, for_actor: actor)
  end

  def work_order_enabled? do
    FunWithFlags.enabled?(@feature_flags.work_orders)
  end

  def work_order_enabled?(%Organization{} = actor) do
    FunWithFlags.enabled?(@feature_flags.work_orders, for: actor)
  end
end
