defmodule Fleetms.VehicleMaintenance.ServiceTask do
  require Ash.Query

  use Ash.Resource,
    domain: Fleetms.VehicleMaintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints max_length: 1000
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :service_group_schedule_service_tasks,
             Fleetms.VehicleMaintenance.ServiceGroupScheduleServiceTask

    has_many :service_reminders, Fleetms.VehicleMaintenance.ServiceReminder
    has_many :work_order_service_tasks, Fleetms.VehicleMaintenance.WorkOrderServiceTask

    has_one :service_reminder, Fleetms.VehicleMaintenance.ServiceReminder do
      source_attribute :id
      destination_attribute :service_task_id
      from_many? true

      filter expr(
               service_task_id == source(id) and
                 vehicle_id == service_task.work_order_service_tasks.work_order.vehicle_id
             )
    end
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
  end

  postgres do
    table "service_tasks"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :list do
      pagination offset?: true, default_limit: 50, countable: true
      prepare build(sort: [updated_at: :desc])
    end

    read :get_all

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))
    end

    read :get_for_form do
      argument :id, :uuid, allow_nil?: false
      argument :vehicle_id, :uuid, default: nil

      filter expr(id == ^arg(:id))

      prepare fn query, _context ->
        service_reminder_query =
          Fleetms.VehicleMaintenance.ServiceReminder
          |> Ash.Query.filter(vehicle_id == ^query.arguments.vehicle_id)
          |> Ash.Query.load(:service_group_name)

        Ash.Query.load(query, [
          :service_reminder,
          service_reminders: service_reminder_query
        ])
      end
    end

    # TODO: Clean up the query repetition in this action and the `list_with_vehicle_reminder_action`
    read :get_with_service_reminder do
      argument :service_task_id, :uuid, allow_nil?: false
      argument :vehicle_id, :uuid, allow_nil?: false

      get? true
      filter expr(id == ^arg(:service_task_id))

      prepare fn query, _context ->
        service_reminder_query =
          Fleetms.VehicleMaintenance.ServiceReminder
          |> Ash.Query.for_read(:read)
          |> Ash.Query.filter(
            vehicle_id == ^query.arguments.vehicle_id and
              service_task_id == ^query.arguments.service_task_id
          )

        Ash.Query.load(query, service_reminders: service_reminder_query)
      end
    end

    read :list_with_vehicle_reminder do
      argument :vehicle_id, :uuid, allow_nil?: false

      prepare fn query, _context ->
        service_reminder_query =
          Fleetms.VehicleMaintenance.ServiceReminder
          |> Ash.Query.filter(vehicle_id == ^query.arguments.vehicle_id)
          |> Ash.Query.load(:service_group_name)

        Ash.Query.load(query, [
          :service_reminder,
          service_reminders: service_reminder_query
        ])
      end
    end
  end

  # calculations do
  #   calculate :vehicle_service_reminders,
  #             :map,
  #             expr(
  #               service_reminders.service_task_id == id and service_reminders.vehicle_id == work_order_service_tasks.work_order.vehicle_id
  #             )

  # end

  code_interface do
    define :get_all, action: :get_all
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :get_for_form, action: :get_for_form, args: [:id, :vehicle_id], get?: true

    define :get_with_service_reminder,
      action: :get_with_service_reminder,
      args: [:service_task_id, :vehicle_id]

    define :list_with_vehicle_reminder,
      action: :list_with_vehicle_reminder,
      args: [:vehicle_id]
  end

  identities do
    identity :unique_name, [:name]
  end

  multitenancy do
    strategy :context
  end
end
