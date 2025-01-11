defmodule Fleetms.VehicleMaintenance.ServiceGroupSchedule do
  use Ash.Resource,
    domain: Fleetms.VehicleMaintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}

  attributes do
    uuid_primary_key :id

    attribute :mileage_interval, :integer do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :hours_interval, :integer do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :time_interval, :integer do
      allow_nil? true
      public? true
    end

    attribute :time_interval_unit, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.time_units()
    end

    attribute :mileage_threshold, :integer do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :hours_threshold, :integer do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :time_threshold, :integer do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :time_threshold_unit, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.time_units()
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :service_group, Fleetms.VehicleMaintenance.ServiceGroup do
      allow_nil? false
    end

    many_to_many :service_tasks, Fleetms.VehicleMaintenance.ServiceTask do
      through Fleetms.VehicleMaintenance.ServiceGroupScheduleServiceTask
      source_attribute_on_join_resource :service_group_schedule_id
      destination_attribute_on_join_resource :service_task_id
    end

    has_many :service_reminders, Fleetms.VehicleMaintenance.ServiceReminder
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      argument :service_group_id, :uuid, allow_nil?: false
      argument :service_tasks, {:array, :uuid}, allow_nil?: true
      argument :vehicles, {:array, :uuid}, default: []

      change fn changeset, _context -> validate_mileage_and_time_attrs(changeset) end

      change manage_relationship(:service_tasks, type: :append_and_remove)
      change manage_relationship(:service_group_id, :service_group, type: :append_and_remove)

      change fn changeset, _context ->
        if changeset.valid? do
          service_group_vehicles = Ash.Changeset.get_argument(changeset, :vehicles)

          service_tasks = Ash.Changeset.get_argument(changeset, :service_tasks)
          attrs = bulk_service_reminders_attrs(changeset, service_tasks, service_group_vehicles)

          changeset
          |> Ash.Changeset.manage_relationship(:service_reminders, attrs,
            authorize?: true,
            identity_priority: [:unique_vehicle_service_reminder],
            use_identities: [:unique_vehicle_service_reminder],
            on_no_match: :create,
            on_match: :update,
            on_missing: {:destroy, :delete_reminder_from_service_group_schedule}
          )
        else
          changeset
        end
      end
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*
      argument :service_group_id, :uuid

      argument :service_tasks, {:array, :uuid}, allow_nil?: true, default: []

      change fn changeset, _context -> validate_mileage_and_time_attrs(changeset) end

      change manage_relationship(:service_tasks, type: :append_and_remove)

      change fn changeset, _context ->
        if changeset.valid? do
          service_group_vehicles =
            Ash.Changeset.get_attribute(changeset, :service_group)
            |> Map.get(:vehicles)

          service_tasks = Ash.Changeset.get_argument(changeset, :service_tasks)

          attrs = bulk_service_reminders_attrs(changeset, service_tasks, service_group_vehicles)

          changeset
          |> Ash.Changeset.manage_relationship(:service_reminders, attrs,
            authorize?: true,
            identity_priority: [:unique_vehicle_service_reminder],
            use_identities: [:unique_vehicle_service_reminder],
            on_no_match: :create,
            on_match: {:update, :update_from_service_group_schedule},
            on_missing: {:destroy, :delete_reminder_from_service_group_schedule}
          )
        else
          changeset
        end
      end
    end

    update :update_from_service_group do
      require_atomic? false
      accept :*
      argument :service_group_id, :uuid

      argument :service_tasks, {:array, :uuid}
      argument :service_reminders, {:array, :map}

      change fn changeset, _context -> validate_mileage_and_time_attrs(changeset) end

      change manage_relationship(:service_tasks, type: :append_and_remove)

      change manage_relationship(:service_reminders,
               authorize?: true,
               identity_priority: [:unique_vehicle_service_reminder],
               use_identities: [:unique_vehicle_service_reminder],
               on_no_match: :create,
               on_match: {:update, :update_from_service_group_schedule},
               on_missing: {:destroy, :delete_reminder_from_service_group_schedule}
             )
    end

    read :get_service_group_schedules do
      argument :service_group_id, :uuid, allow_nil?: false

      pagination offset?: true, default_limit: 20, countable: true

      filter expr(service_group_id == ^arg(:service_group_id))
      prepare build(load: [:service_tasks], limit: 20)
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))
      prepare build(load: [:service_tasks, service_group: [:vehicles]])
    end
  end

  code_interface do
    define :get_by_id, action: :get_by_id, args: [:id], get?: true

    define :get_service_group_schedules,
      action: :get_service_group_schedules,
      args: [:service_group_id]
  end

  policies do
    policy action_type(:action) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if accessing_from(Fleetms.VehicleMaintenance.ServiceGroup, :service_group_schedules)
    end

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if accessing_from(Fleetms.VehicleMaintenance.ServiceGroup, :service_group_schedules)
    end

    policy action(:update_from_service_group) do
      authorize_if accessing_from(Fleetms.VehicleMaintenance.ServiceGroup, :service_group_schedules)
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if accessing_from(Fleetms.VehicleMaintenance.ServiceGroup, :service_group_schedules)
    end
  end

  postgres do
    table "service_group_schedules"
    repo Fleetms.Repo

    references do
      reference :service_group, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  defp validate_mileage_and_time_attrs(changeset) do
    time_interval = Ash.Changeset.get_attribute(changeset, :time_interval)
    time_interval_unit = Ash.Changeset.get_attribute(changeset, :time_interval_unit)
    time_threshold = Ash.Changeset.get_attribute(changeset, :time_threshold)
    time_threshold_unit = Ash.Changeset.get_attribute(changeset, :time_threshold_unit)

    mileage_interval = Ash.Changeset.get_attribute(changeset, :mileage_interval)
    mileage_threshold = Ash.Changeset.get_attribute(changeset, :mileage_threshold)

    cond do
      is_nil(time_interval) && is_nil(mileage_interval) ->
        changeset
        |> Ash.Changeset.add_error(
          field: :time_interval,
          message: "Time interval or mileage interval must be specified or both"
        )
        |> Ash.Changeset.add_error(
          field: :mileage_interval,
          message: "Time interval or mileage interval must be specified or both"
        )

      time_interval && is_nil(time_interval_unit) ->
        changeset
        |> Ash.Changeset.add_error(
          field: :time_interval_unit,
          message: "Time interval unit must be specified"
        )

      is_nil(time_interval) && time_interval_unit ->
        changeset
        |> Ash.Changeset.add_error(
          field: :time_interval,
          message: "Time interval must be specified, or set Time interval unit to nothing"
        )

      time_threshold && is_nil(time_threshold_unit) ->
        changeset
        |> Ash.Changeset.add_error(
          field: :time_threshold_unit,
          message: "Time threshold unit must be specified"
        )

      time_threshold && is_nil(time_interval) ->
        changeset
        |> Ash.Changeset.add_error(
          field: :time_threshold,
          message: "Cannot set Time threshold without setting Time interval"
        )

      mileage_threshold && is_nil(mileage_interval) ->
        changeset
        |> Ash.Changeset.add_error(
          field: :mileage_threshold,
          message: "Cannot set Mileage threshold without setting Mileage interval"
        )

      is_nil(time_threshold) && time_threshold_unit ->
        changeset
        |> Ash.Changeset.add_error(
          field: :time_threshold,
          message: "Time threshold must be specified, or set Time threshold unit to nothing"
        )

      true ->
        changeset
    end
  end

  def bulk_service_reminders_attrs(resource_or_changeset, service_tasks, vehicles) do
    get_vehicle_id = fn vehicle -> if is_binary(vehicle), do: vehicle, else: vehicle.id end

    get_service_task_id = fn service_task ->
      if is_binary(service_task), do: service_task, else: service_task.id
    end

    if is_list(service_tasks) and is_list(vehicles) do
      for service_task <- service_tasks, vehicle <- vehicles do
        %{
          service_task_id: get_service_task_id.(service_task),
          vehicle_id: get_vehicle_id.(vehicle),
          mileage_interval: get_values_for_reminder(resource_or_changeset, :mileage_interval),
          time_interval: get_values_for_reminder(resource_or_changeset, :time_interval),
          time_interval_unit: get_values_for_reminder(resource_or_changeset, :time_interval_unit),
          mileage_threshold: get_values_for_reminder(resource_or_changeset, :mileage_threshold),
          time_threshold: get_values_for_reminder(resource_or_changeset, :time_threshold),
          time_threshold_unit:
            get_values_for_reminder(resource_or_changeset, :time_threshold_unit)
        }
      end
    else
      []
    end
  end

  def get_values_for_reminder(%Ash.Changeset{} = changeset, key) do
    Ash.Changeset.get_attribute(changeset, key)
  end

  def get_values_for_reminder(%_struct{} = resource, key) do
    Map.get(resource, key)
  end
end
