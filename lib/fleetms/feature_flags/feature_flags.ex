defmodule Fleetms.FeatureFlags do
  @fields [
    :user_registration,
    :vehicles,
    :vehicle_assignments,
    :vehicle_reminders,
    :inspection_forms,
    :inspection_submissions,
    :issues,
    :service_groups,
    :service_tasks,
    :service_reminders,
    :work_orders,
    :parts,
    :inventory_location,
    :fuel_histories,
    :reports,
    :vehicles_module,
    :inspections_module,
    :issues_module,
    :service_module,
    :inventory_module,
    :fuel_tracking_module,
    :user_management
  ]
  @enforce_keys @fields
  defstruct @fields

  alias Fleetms.Accounts.Organization

  def get_flags do
    fields = for field <- @fields, into: %{}, do: {field, field}

    struct!(__MODULE__, fields)
  end

  def enable_all(%Organization{} = actor) do
    for flag <- @fields do
      FunWithFlags.enable(flag, for_actor: actor)
    end
  end

  def disable_all(%Organization{} = actor) do
    for flag <- @fields do
      FunWithFlags.disable(flag, for_actor: actor)
    end
  end
end
