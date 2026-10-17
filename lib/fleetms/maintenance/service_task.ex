defmodule Fleetms.Maintenance.ServiceTask do
  @moduledoc """
  A reusable definition of a piece of maintenance work — "Oil & filter change",
  "Brake inspection", "Tyre rotation" — scoped to an organization.

  Service tasks are a catalogue: they carry no cost or schedule of their own.
  Instead they're the shared vocabulary that work orders reference (what work was
  done, with its own parts and labour) and that service reminders track (when this
  task is next due on a vehicle). Keeping the definition in one place means renaming
  a task, or reporting on it across vehicles, works off a single record.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "service_tasks"
    repo Fleetms.Repo
  end

  permissions do
    permission :view_service_tasks,
      action: :read,
      label: "View Service Tasks",
      group: "Maintenance"

    permission :create_service_task,
      action: :create,
      label: "Create Service Task",
      group: "Maintenance"

    permission :update_service_task,
      action: :update,
      label: "Update Service Task",
      group: "Maintenance"

    permission :delete_service_task,
      action: :destroy,
      label: "Delete Service Task",
      group: "Maintenance"
  end

  json_api do
    type "service-task"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list do
      argument :search_query, :string, default: ""

      argument :sort_by, :atom do
        constraints one_of: [:name, :inserted_at]
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

      prepare Fleetms.Maintenance.ServiceTask.Preparations.ListServiceTasks
    end

    create :create do
      primary? true
      accept [:name, :description]
    end

    update :update do
      primary? true
      accept [:name, :description]
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
      authorize_if has_permission(:view_service_tasks)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_service_task)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_service_task)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_service_task)
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

  identities do
    identity :unique_name, [:name]
  end
end
