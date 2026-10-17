defmodule Fleetms.Maintenance.ServiceGroup do
  @moduledoc """
  A shared maintenance programme applied to many vehicles at once.

  A group is a set of **schedule lines** (each a service task + its intervals) and a
  set of member **vehicles**. Every (schedule line × member vehicle) pair is a
  `ServiceReminder`, generated and kept in sync automatically: add a vehicle and it
  gets the group's reminders; edit a schedule and every member's matching reminder
  is updated; remove either and the now-orphaned reminders are cleaned up. The
  fan-out runs after each create/update via `Changes.SyncGroupReminders`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Maintenance

  postgres do
    table "service_groups"
    repo Fleetms.Repo
  end

  permissions do
    permission :view_service_groups,
      action: :read,
      label: "View Service Groups",
      group: "Maintenance"

    permission :create_service_group,
      action: :create,
      label: "Create Service Group",
      group: "Maintenance"

    permission :update_service_group,
      action: :update,
      label: "Update Service Group",
      group: "Maintenance"

    permission :delete_service_group,
      action: :destroy,
      label: "Delete Service Group",
      group: "Maintenance"
  end

  json_api do
    type "service-group"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id

      prepare build(
                load: [
                  :vehicle_count,
                  :schedule_count,
                  vehicles: [:name],
                  schedules: [:service_task_name]
                ]
              )
    end

    read :list do
      argument :search_query, :string, default: ""

      argument :sort_by, :atom do
        constraints one_of: [:name, :vehicle_count, :schedule_count, :inserted_at]
        default :name
      end

      argument :sort_order, :atom do
        constraints one_of: [:asc, :desc]
        default :asc
      end

      pagination offset?: true,
                 countable: true,
                 default_limit: 20,
                 max_page_size: 100,
                 required?: false

      prepare Maintenance.ServiceGroup.Preparations.ListServiceGroups
    end

    create :create do
      primary? true
      accept [:name, :description]

      argument :vehicle_ids, {:array, :uuid}, default: []
      argument :schedules, {:array, :map}, default: []

      change manage_relationship(:vehicle_ids, :vehicles, type: :append_and_remove)
      change manage_relationship(:schedules, type: :direct_control)
      change Maintenance.ServiceGroup.Changes.SyncGroupReminders
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :description]

      argument :vehicle_ids, {:array, :uuid}, default: []
      argument :schedules, {:array, :map}, default: []

      change manage_relationship(:vehicle_ids, :vehicles, type: :append_and_remove)
      change manage_relationship(:schedules, type: :direct_control)
      change Maintenance.ServiceGroup.Changes.SyncGroupReminders
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_service_groups)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_service_group)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_service_group)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_service_group)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    has_many :schedules, Fleetms.Maintenance.ServiceGroupSchedule
    has_many :service_group_vehicles, Fleetms.Maintenance.ServiceGroupVehicle

    many_to_many :vehicles, Fleetms.VehicleManagement.Vehicle do
      through Fleetms.Maintenance.ServiceGroupVehicle
      join_relationship :service_group_vehicles
      source_attribute_on_join_resource :service_group_id
      destination_attribute_on_join_resource :vehicle_id
    end
  end

  aggregates do
    count :vehicle_count, :vehicles
    count :schedule_count, :schedules
  end

  identities do
    identity :unique_name, [:name]
  end
end
