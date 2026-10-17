defmodule Fleetms.Maintenance.WorkOrder do
  @moduledoc """
  A record of maintenance work carried out (or to be carried out) on one vehicle.

  A work order gathers the service tasks performed, each with its own parts (and,
  later, labour), and moves through a small lifecycle managed by `AshStateMachine`:
  `open → in_progress → completed`, with the ability to reopen a completed order.
  Lifecycle transitions are explicit actions (`start`/`complete`/`reopen`) rather
  than free-form status edits, so each stamps its own timestamp and illegal jumps
  are rejected.

  Each order carries a per-organization sequential `work_order_number` (shown as
  "#42"), a meter snapshot, and identifying detail. Costs are derived from the line
  items' parts and labour (see `Fleetms.Maintenance.Costs`). Completing an order
  applies its side-effects in the same transaction (consume flagged parts from
  stock, reset matching reminders, resolve linked issues) — see
  `Changes.ApplyCompletionEffects`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      Fleetms.Permissions.Dsl,
      AshStateMachine,
      AshArchival.Resource,
      AshPaperTrail.Resource,
      AshJsonApi.Resource
    ],
    # Owner-scopes work orders for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Maintenance

  # Attributes accepted by create/update. Status and its timestamps are set only by
  # the lifecycle transition actions, and the number is sequence-assigned.
  @writable_attrs [
    :description,
    :comments,
    :mileage,
    :hours,
    :repair_category,
    :issued_at
  ]

  postgres do
    table "work_orders"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where`).
    identity_wheres_to_sql unique_work_order_number: "archived_at IS NULL"

    references do
      reference :vehicle, on_delete: :delete
      reference :assigned_to, on_delete: :nilify
      reference :issued_by, on_delete: :nothing
    end

    # Per-tenant sequence backing `work_order_number`. `code? true` so the statement
    # is emitted as migration code and schema-qualifies with `prefix()` — otherwise
    # the sequence lands in `public`, shared across all orgs. Drawn from in
    # `Changes.SetWorkOrderNumber`. Mirrors the issues sequence.
    custom_statements do
      statement :work_order_number_sequence do
        code? true
        up ~S|execute("CREATE SEQUENCE IF NOT EXISTS \"#{prefix()}\".work_orders_number_seq")|
        down ~S|execute("DROP SEQUENCE IF EXISTS \"#{prefix()}\".work_orders_number_seq")|
      end
    end
  end

  permissions do
    permission :view_work_orders,
      action: :read,
      label: "View Work Orders",
      group: "Maintenance"

    permission :create_work_order,
      action: :create,
      label: "Create Work Order",
      group: "Maintenance"

    permission :update_work_order,
      action: [:update, :start, :complete, :reopen],
      label: "Update Work Order",
      group: "Maintenance"

    permission :delete_work_order,
      action: :destroy,
      label: "Delete Work Order",
      group: "Maintenance"
  end

  state_machine do
    initial_states [:open]
    default_initial_state :open
    state_attribute :status

    transitions do
      transition :start, from: [:open], to: :in_progress
      transition :complete, from: [:open, :in_progress], to: :completed
      transition :reopen, from: [:completed], to: :in_progress
    end
  end

  # Soft delete (AshArchival), Option B: `destroy` archives the work order, keeping its
  # photos/documents and their stored files so it can be recovered. Archived work orders
  # are hidden from the browse lists (see the filters on `:list`/`:list_by_vehicle`), but
  # still resolve via `get_by_id` and via the relationship (`:read`) — so an issue that
  # links to one keeps its history. The real hard delete (rows + storage cleanup) lives on
  # the separate `:purge` action, which is excluded from archival.
  archive do
    exclude_destroy_actions([:purge])
    # `:list_archived` shows only archived work orders, so it opts out of the automatic
    # `is_nil(archived_at)` filter and applies its own `not is_nil(archived_at)`.
    exclude_read_actions([:read, :get_by_id, :list_archived])
  end

  # Audit trail (AshPaperTrail): every create/update/destroy writes a `work_orders_versions`
  # row (in the tenant schema) with the acting user, the action name and a full diff. The
  # History tab derives a readable timeline from these.
  paper_trail do
    change_tracking_mode(:full_diff)
    store_action_name?(true)
    reference_source?(false)
    ignore_attributes([:inserted_at, :updated_at])
    belongs_to_actor(:user, Fleetms.Accounts.User, domain: Fleetms.Accounts)
  end

  json_api do
    type "work-order"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id

      prepare build(
                load: [
                  :service_task_count,
                  :photos,
                  :documents,
                  vehicle: [:name],
                  issues: [:issue_number, :title, :status],
                  assigned_to: [:email, profile: [:first_name, :last_name]],
                  issued_by: [:email, profile: [:first_name, :last_name]],
                  work_order_service_tasks: [
                    :service_task_name,
                    work_order_service_task_parts: [part: [:name, :part_number]],
                    labor_items: [
                      technician: [profile: [:first_name, :last_name]],
                      vendor: [:name]
                    ]
                  ]
                ]
              )
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :work_order_number
        constraints one_of: [:work_order_number, :issued_at, :status, :completed_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      # Browse/pick list hides archived work orders (Option B — see the archive block).
      filter expr(is_nil(archived_at))
      prepare Maintenance.WorkOrder.Preparations.ListWorkOrders
    end

    # The mirror of `:list` for the archived view: only archived work orders.
    read :list_archived do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :work_order_number
        constraints one_of: [:work_order_number, :issued_at, :status, :completed_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare Maintenance.WorkOrder.Preparations.ListWorkOrders
    end

    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false
      filter expr(vehicle_id == ^arg(:vehicle_id) and is_nil(archived_at))
      prepare build(load: [:service_task_count], sort: [work_order_number: :desc])
    end

    create :create do
      primary? true
      accept @writable_attrs

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :assigned_to_id, :uuid
      argument :work_order_service_tasks, {:array, :map}
      argument :issue_ids, {:array, :uuid}, default: []
      argument :tags, {:array, :string}

      change relate_actor(:issued_by)

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:assigned_to_id, :assigned_to, type: :append_and_remove)

      change manage_relationship(:work_order_service_tasks, type: :direct_control)

      change manage_relationship(:issue_ids, :issues,
               on_lookup: {:relate, :link_to_work_order},
               on_match: :ignore,
               on_no_match: :error,
               on_missing: {:unrelate, :link_to_work_order}
             )

      change Maintenance.WorkOrder.Changes.SetWorkOrderNumber
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :assigned_to_id, :uuid
      argument :work_order_service_tasks, {:array, :map}
      argument :issue_ids, {:array, :uuid}, default: []
      argument :tags, {:array, :string}

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:assigned_to_id, :assigned_to, type: :append_and_remove)

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )

      change manage_relationship(:work_order_service_tasks, type: :direct_control)

      change manage_relationship(:issue_ids, :issues,
               on_lookup: {:relate, :link_to_work_order},
               on_match: :ignore,
               on_no_match: :error,
               on_missing: {:unrelate, :link_to_work_order}
             )
    end

    update :start do
      description "Move an open work order into progress."
      require_atomic? false

      change transition_state(:in_progress)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end

    update :complete do
      description "Mark the work order completed and apply its side-effects."
      require_atomic? false
      accept [:comments]

      change transition_state(:completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change Maintenance.WorkOrder.Changes.ApplyCompletionEffects
    end

    update :reopen do
      description "Reopen a completed work order to resume work."
      require_atomic? false

      change transition_state(:in_progress)
      change set_attribute(:completed_at, nil)
    end

    # Bring an archived work order back into the active lists. Non-atomic: writing an
    # audit version (AshPaperTrail full_diff) can't run atomically.
    update :restore do
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end

    # Archives the work order (AshArchival). Its photos/documents and their stored files
    # are kept so it can be recovered — the storage cleanup lives on `:purge`.
    destroy :destroy do
      primary? true
      require_atomic? false
    end

    # The real, permanent delete: removes the row (the FK cascade removes the photo/
    # document rows) and cleans up their stored bytes. Excluded from archival.
    destroy :purge do
      require_atomic? false

      # The FK cascade removes the photo/document rows, but not their stored bytes.
      # Capture the keys *before* the delete (the cascade wipes the rows during it),
      # then delete the objects from storage after the transaction commits.
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.before_action(fn changeset ->
          work_order = Ash.load!(changeset.data, [:photos, :documents], authorize?: false)

          keys =
            Enum.flat_map(work_order.photos, &[&1.image_key, &1.thumbnail_key]) ++
              Enum.map(work_order.documents, & &1.storage_key)

          Ash.Changeset.set_context(changeset, %{media_keys: keys})
        end)
        |> Ash.Changeset.after_transaction(fn changeset, result ->
          with {:ok, _} <- result do
            Enum.each(Map.get(changeset.context, :media_keys, []), &Fleetms.Storage.delete/1)
          end

          result
        end)
      end
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_work_orders)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_work_order)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_work_order)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_work_order)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :work_order_number, :integer do
      allow_nil? false
      public? true
      writable? false
      description "Per-organization sequential identifier shown as “#42”."
    end

    attribute :description, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :comments, :string do
      public? true
      constraints max_length: 2000
    end

    attribute :mileage, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
      description "Vehicle mileage snapshot when the work order was raised."
    end

    attribute :hours, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
      description "Vehicle engine hours snapshot when the work order was raised."
    end

    attribute :repair_category, Maintenance.RepairCategory, public?: true

    attribute :issued_at, :utc_datetime do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
      description "When the work order was raised."
    end

    attribute :started_at, :utc_datetime, public?: true
    attribute :completed_at, :utc_datetime, public?: true

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :issued_by, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? false
      public? true
      description "The member who raised the work order (the acting user)."
    end

    belongs_to :assigned_to, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
      attribute_writable? true
      description "The member responsible for carrying out the work."
    end

    has_many :work_order_service_tasks, Fleetms.Maintenance.WorkOrderServiceTask

    has_many :issues, Fleetms.VehicleIssues.Issue do
      domain Fleetms.VehicleIssues
    end

    has_many :photos, Fleetms.Maintenance.WorkOrderPhoto
    has_many :documents, Fleetms.Maintenance.WorkOrderDocument

    many_to_many :service_tasks, Fleetms.Maintenance.ServiceTask do
      through Fleetms.Maintenance.WorkOrderServiceTask
      source_attribute_on_join_resource :work_order_id
      destination_attribute_on_join_resource :service_task_id
    end

    many_to_many :tags, Fleetms.Tagging.Tag do
      domain Fleetms.Tagging
      through Fleetms.Tagging.Tagging
      source_attribute_on_join_resource :work_order_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  aggregates do
    count :service_task_count, :work_order_service_tasks
  end

  identities do
    # Partial index: numbers are unique only among non-archived work orders.
    identity :unique_work_order_number, [:work_order_number] do
      where expr(is_nil(archived_at))
    end
  end
end
