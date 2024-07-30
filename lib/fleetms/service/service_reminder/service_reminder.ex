defmodule Fleetms.Service.ServiceReminder do
  require Ash.Resource.Change.Builtins

  use Ash.Resource,
    domain: Fleetms.Service,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query
  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}

  attributes do
    uuid_primary_key :id

    attribute :mileage_interval, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :hours_interval, :decimal do
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

    attribute :mileage_threshold, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :hours_threshold, :decimal do
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

    attribute :last_completed_mileage, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      writable? false
    end

    attribute :last_completed_hours, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      writable? false
    end

    attribute :last_completed_date, :date do
      allow_nil? true
      public? true
      writable? false
    end

    attribute :next_due_mileage, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
      writable? false
    end

    attribute :next_due_hours, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
      writable? false
    end

    attribute :next_due_date, :date do
      allow_nil? true
      public? true
      writable? false
    end

    attribute :due_status, :atom do
      allow_nil? false
      public? true
      constraints one_of: Fleetms.Enums.service_reminder_statuses()
      default :Upcoming
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :service_group_schedule, Fleetms.Service.ServiceGroupSchedule

    belongs_to :service_task, Fleetms.Service.ServiceTask do
      allow_nil? false
    end

    belongs_to :vehicle, Fleetms.Vehicles.Vehicle do
      domain Fleetms.Vehicles
      allow_nil? false
    end

    has_many :service_reminder_histories, Fleetms.Service.ServiceReminderHistory
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
    end

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action([:update, :destroy]) do
      # We only allow updating the reminder if it has no service group. Reminders that have a service group should be updated from the service group.
      authorize_if Fleetms.Service.Authorizers.ReminderHasNoServiceGroup
    end

    policy action(:update_from_vehicle) do
      authorize_if accessing_from(Fleetms.Vehicles.Vehicle, :service_reminders)
    end

    policy action([:update_by_work_order_completion, :update_by_work_order_reopen]) do
      authorize_if always()
    end

    policy action([
             :update_from_service_group_schedule,
             :delete_reminder_from_service_group_schedule
           ]) do
      authorize_if accessing_from(Fleetms.Service.ServiceGroupSchedule, :service_reminders)
      authorize_if Fleetms.Service.Authorizers.ReminderBelongsToServiceGroupSchedule
    end
  end

  postgres do
    table "service_reminders"
    repo Fleetms.Repo

    references do
      reference :service_group_schedule, on_delete: :delete
      reference :vehicle, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    action :get_dashboard_stats, :map do
      import Ecto.Query
      argument :tenant, :string, allow_nil?: false

      run fn input, _context ->
        tenant = input.arguments.tenant

        {:ok, service_reminder_ecto_query} =
          Fleetms.Service.ServiceReminder
          |> Ash.Query.set_tenant(tenant)
          |> Ash.Query.data_layer_query()

        {:ok, service_task_ecto_query} =
          Fleetms.Service.ServiceTask
          |> Ash.Query.set_tenant(tenant)
          |> Ash.Query.data_layer_query()

        status_counts_query =
          from s in subquery(service_reminder_ecto_query),
            select: %{
              upcoming: count(s.id) |> filter(s.due_status == :Upcoming),
              due_soon: count(s.id) |> filter(s.due_status == :"Due Soon"),
              overdue: count(s.id) |> filter(s.due_status == :Overdue)
            }

        due_soon_service_task_count_query =
          from service_reminder in subquery(service_reminder_ecto_query),
            join: service_task in subquery(service_task_ecto_query),
            on: service_reminder.service_task_id == service_task.id,
            where: service_reminder.due_status == :"Due Soon",
            group_by: [service_task.id, service_task.name],
            select: %{
              service_task_name: service_task.name,
              task_count: count("*"),
              vehicles: count(service_reminder.vehicle_id)
            },
            order_by: [desc: count("*")],
            limit: 5

        overdue_service_task_count_query =
          from service_reminder in subquery(service_reminder_ecto_query),
            join: service_task in subquery(service_task_ecto_query),
            on: service_reminder.service_task_id == service_task.id,
            where: service_reminder.due_status == :Overdue,
            group_by: [service_task.id, service_task.name],
            select: %{
              service_task_name: service_task.name,
              task_count: count("*"),
              vehicles: count(service_reminder.vehicle_id)
            },
            order_by: [desc: count("*")],
            limit: 5

        data = %{
          status_counts: Fleetms.Repo.one(status_counts_query),
          due_soon_service_task_count: Fleetms.Repo.all(due_soon_service_task_count_query),
          overdue_service_task_count: Fleetms.Repo.all(overdue_service_task_count_query)
        }

        {:ok, data}
      end
    end

    create :create do
      primary? true
      accept :*

      argument :service_group_schedule_id, :uuid do
        allow_nil? true
      end

      argument :service_task_id, :uuid do
        allow_nil? false
      end

      argument :vehicle_id, :uuid do
        allow_nil? false
      end

      change fn changeset, _context ->
        validate_mileage_and_time_attrs(changeset)
      end

      change manage_relationship(:service_group_schedule_id, :service_group_schedule,
               type: :append_and_remove
             )

      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)
      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)

      change Fleetms.Service.ServiceReminder.Changes.SetNextDue do
        only_when_valid? true
      end

      change Fleetms.Service.ServiceReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    create :ignore_create

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :service_group_schedule_id, :uuid do
        allow_nil? true
      end

      argument :service_task_id, :uuid, allow_nil?: false

      argument :vehicle_id, :uuid, allow_nil?: false

      change fn changeset, _context -> validate_mileage_and_time_attrs(changeset) end

      change manage_relationship(:service_group_schedule_id, :service_group_schedule,
               type: :append_and_remove
             )

      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)
      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)

      change Fleetms.Service.ServiceReminder.Changes.SetNextDue do
        only_when_valid? true
      end

      change Fleetms.Service.ServiceReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    update :update_from_service_group_schedule do
      require_atomic? false
      accept :*
      argument :service_group_schedule_id, :uuid

      argument :service_task_id, :uuid

      argument :vehicle_id, :uuid

      change fn changeset, _context -> validate_mileage_and_time_attrs(changeset) end

      change manage_relationship(:service_group_schedule_id, :service_group_schedule,
               type: :append_and_remove
             )

      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)
      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)

      change Fleetms.Service.ServiceReminder.Changes.SetNextDue do
        only_when_valid? true
      end

      change Fleetms.Service.ServiceReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    update :update_from_vehicle do
      require_atomic? false
      accept :*
      argument :vehicle_id, :uuid
      argument :vehicle_mileage, :decimal, allow_nil?: false

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)

      change Fleetms.Service.ServiceReminder.Changes.SetNextDue do
        only_when_valid? true
      end

      change Fleetms.Service.ServiceReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    update :reminder_with_service_group_schedule do
      require_atomic? false
      accept :*
    end

    update :ignore_update do
      require_atomic? false
    end

    update :update_by_work_order_completion do
      require_atomic? false

      change Fleetms.Service.ServiceReminder.Changes.SetNextDue do
        only_when_valid? true
      end

      change Fleetms.Service.ServiceReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    update :update_by_work_order_reopen do
      require_atomic? false
      accept :*
      argument :last_completed_mileage, :decimal, allow_nil?: false
      argument :last_completed_date, :date, allow_nil?: false

      change Fleetms.Service.ServiceReminder.Changes.SetNextDue do
        only_when_valid? true
      end

      change Fleetms.Service.ServiceReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    read :list do
      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      pagination offset?: true, default_limit: 50, countable: true

      prepare fn query, _context ->
        %{sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        advanced_filter_params = Ash.Query.get_argument(query, :advanced_filter_params)

        query =
          Enum.reduce(advanced_filter_params, query, fn
            {_, nil}, accumulated_query ->
              accumulated_query

            {_, []}, accumulated_query ->
              accumulated_query

            {_, "All"}, accumulated_query ->
              accumulated_query

            {_, :All}, accumulated_query ->
              accumulated_query

            {:due_statuses, statuses}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(due_status in ^statuses))

            {:mileage_interval_min, mileage_interval_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage_interval >= ^mileage_interval_min))

            {:mileage_interval_max, mileage_interval_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage_interval <= ^mileage_interval_max))

            {:time_interval_min, time_interval_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(time_interval >= ^time_interval_min))

            {:time_interval_max, time_interval_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(time_interval <= ^time_interval_max))

            {:time_interval_unit, time_interval_unit}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(time_interval_unit == ^time_interval_unit))

            {:mileage_next_due_min, mileage_next_due_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage_next_due >= ^mileage_next_due_min))

            {:mileage_next_due_max, mileage_next_due_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage_next_due <= ^mileage_next_due_max))

            {:next_due_date_from, next_due_date_from}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(next_due_date >= ^next_due_date_from))

            {:next_due_date_to, next_due_date_to}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(next_due_date <= ^next_due_date_to))

            {:service_groups, service_group_ids}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(service_group_schedule.service_group.id in ^service_group_ids)
              )

            {:vehicles, vehicle_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_id in ^vehicle_ids))

            {:service_tasks, service_task_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(service_task_id in ^service_task_ids))

            _, accumulated_query ->
              accumulated_query
          end)
          |> Ash.Query.sort([{sort_by, sort_order}])
          |> Ash.Query.load([
            :service_task,
            :service_group_name,
            :vehicle_mileage,
            :mileage_remaining,
            vehicle: [:full_name]
          ])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(vehicle.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.vehicle_make.name, ^search_query) > 0.1 or
                trigram_similarity(service_group_name, ^search_query) > 0.3 or
                trigram_similarity(service_task.name, ^search_query) > 0.1 or
                trigram_similarity(due_status, ^search_query) > 0.3
            )
          )
        end
      end
    end

    read :get_all

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      prepare build(
                load: [
                  :service_task,
                  :service_group_name,
                  :vehicle_mileage,
                  vehicle: [:full_name],
                  service_group_schedule: [:service_group]
                ]
              )

      filter expr(id == ^arg(:id))
    end

    read :get_for_form do
      argument :id, :uuid, allow_nil?: false

      prepare build(
                load: [
                  :vehicle_mileage,
                  :service_task,
                  :service_group_schedule,
                  :service_group_name
                ]
              )

      filter expr(id == ^arg(:id))
    end

    read :list_vehicle_service_reminders do
      argument :vehicle_id, :uuid, allow_nil?: false

      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(load: [:service_task])
      pagination offset?: true, default_limit: 30, countable: true
    end

    read :get_by_vehicle_id do
      argument :vehicle_id, :uuid, allow_nil?: false

      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(load: [:service_group_name, :service_task])
    end

    destroy :delete_reminder_from_service_group_schedule
  end

  code_interface do
    define :get_all, action: :get_all
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :get_for_form, action: :get_for_form, args: [:id], get?: true
    define :get_by_vehicle_id, action: :get_by_vehicle_id, args: [:vehicle_id]
    define :get_dashboard_stats, action: :get_dashboard_stats, args: [:tenant]
  end

  aggregates do
    first :service_group_name, [:service_group_schedule, :service_group], :name do
      filterable? true
    end

    first :service_task_name, :service_task, :name do
      filterable? true
    end

    first :vehicle_mileage, :vehicle, :mileage
  end

  calculations do
    calculate :mileage_remaining, :integer, expr(next_due_mileage - vehicle_mileage)
  end

  identities do
    identity :unique_vehicle_service_reminder, [:vehicle_id, :service_task_id],
      eager_check_with: Fleetms.Service
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
end
