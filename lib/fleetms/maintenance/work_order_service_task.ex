defmodule Fleetms.Maintenance.WorkOrderServiceTask do
  @moduledoc """
  A single service task performed on a work order — the line item that ties a work
  order to one `ServiceTask` and holds the parts used for it (labour is added in a
  later slice).

  Managed entirely through its parent work order (`type: :direct_control`): the
  work-order form adds, edits, and removes these rows, and cascades the nested
  parts. There are no standalone create/update actions on the domain.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "work_order_service_tasks"
    repo Fleetms.Repo

    references do
      reference :work_order, on_delete: :delete
      reference :service_task, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    # Freezes the service task's name onto the line at work-order completion (see the
    # matching action on WorkOrderServiceTaskPart). Called only from
    # WorkOrder.Changes.ApplyCompletionEffects (authorize?: false).
    update :freeze_snapshot do
      require_atomic? false
      argument :service_task_name, :string
      change set_attribute(:service_task_name_snapshot, arg(:service_task_name))
    end

    create :create do
      primary? true

      argument :service_task_id, :uuid, allow_nil?: false
      argument :work_order_service_task_parts, {:array, :map}
      argument :labor_items, {:array, :map}

      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)

      change manage_relationship(:work_order_service_task_parts, type: :direct_control)
      change manage_relationship(:labor_items, type: :direct_control)
    end

    update :update do
      primary? true
      require_atomic? false

      argument :service_task_id, :uuid
      argument :work_order_service_task_parts, {:array, :map}
      argument :labor_items, {:array, :map}

      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)

      change manage_relationship(:work_order_service_task_parts, type: :direct_control)
      change manage_relationship(:labor_items, type: :direct_control)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if accessing_from(Fleetms.Maintenance.WorkOrder, :work_order_service_tasks)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    # The service task's name, frozen when the work order completes (nil while open —
    # the `service_task_name` aggregate serves the live name until then). Lets a
    # finished order keep its labels even if the catalogue task is later renamed.
    attribute :service_task_name_snapshot, :string do
      public? true
      writable? false
      description "The service task's name, frozen at work-order completion."
    end

    timestamps()
  end

  relationships do
    belongs_to :work_order, Fleetms.Maintenance.WorkOrder do
      allow_nil? false
    end

    belongs_to :service_task, Fleetms.Maintenance.ServiceTask do
      allow_nil? false
      public? true
    end

    has_many :work_order_service_task_parts, Fleetms.Maintenance.WorkOrderServiceTaskPart
    has_many :labor_items, Fleetms.Maintenance.WorkOrderServiceTaskLaborItem
  end

  aggregates do
    first :service_task_name, :service_task, :name
    count :parts_count, :work_order_service_task_parts
    count :labor_items_count, :labor_items
  end
end
