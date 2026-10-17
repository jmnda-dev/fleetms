defmodule Fleetms.Maintenance.WorkOrderServiceTaskPart do
  @moduledoc """
  A part used for a service task on a work order: which part, how many, at what unit
  cost, and (optionally) which stock location it should come from.

  `subtotal` is derived on write as `unit_cost × quantity` and stored, so a work
  order's costs stay fixed to what was charged at the time even if the part's
  catalogue price later changes. `consume_stock?` marks a line that should draw its
  quantity down from inventory when the work order is completed; it is derived from
  whether a stock location was chosen (see `Changes.SetConsumeFromLocation`), and the
  draw-down happens in `WorkOrder.Changes.ApplyCompletionEffects`.

  Managed through its parent work-order service task (`type: :direct_control`).
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "work_order_service_task_parts"
    repo Fleetms.Repo

    references do
      reference :work_order_service_task, on_delete: :delete
      reference :part, on_delete: :delete
      reference :inventory_location, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    # Freezes the part's name/number onto the line when the work order completes, so a
    # later rename of the catalogue part doesn't rewrite the label on a finished order.
    # Called only from WorkOrder.Changes.ApplyCompletionEffects (authorize?: false).
    update :freeze_snapshot do
      require_atomic? false
      argument :part_name, :string
      argument :part_number, :string
      change set_attribute(:part_name, arg(:part_name))
      change set_attribute(:part_number, arg(:part_number))
    end

    create :create do
      primary? true
      accept [:quantity, :unit_cost, :comments]

      argument :part_id, :uuid, allow_nil?: false
      argument :inventory_location_id, :uuid

      change manage_relationship(:part_id, :part, type: :append_and_remove)

      change manage_relationship(:inventory_location_id, :inventory_location,
               type: :append_and_remove
             )

      change Fleetms.Maintenance.WorkOrderServiceTaskPart.Changes.SetConsumeFromLocation
      change Fleetms.Maintenance.WorkOrderServiceTaskPart.Changes.CalculateSubtotal
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:quantity, :unit_cost, :comments]

      argument :part_id, :uuid
      argument :inventory_location_id, :uuid

      change manage_relationship(:part_id, :part, type: :append_and_remove)

      change manage_relationship(:inventory_location_id, :inventory_location,
               type: :append_and_remove
             )

      change Fleetms.Maintenance.WorkOrderServiceTaskPart.Changes.SetConsumeFromLocation
      change Fleetms.Maintenance.WorkOrderServiceTaskPart.Changes.CalculateSubtotal
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
      authorize_if accessing_from(
                     Fleetms.Maintenance.WorkOrderServiceTask,
                     :work_order_service_task_parts
                   )
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      default Decimal.new(1)
      constraints min: 0, max: 999_999_999
    end

    attribute :unit_cost, AshMoney.Types.Money do
      public? true
      description "What one unit was charged at on this work order."
    end

    attribute :subtotal, AshMoney.Types.Money do
      public? true
      writable? false
      description "Derived unit_cost × quantity, frozen at write time."
    end

    attribute :comments, :string do
      public? true
      constraints max_length: 500
    end

    # Snapshots of the part's identity, frozen when the work order completes (nil while
    # the order is still open — the display falls back to the live part). Keeps a
    # finished order's line items reading what they were, even if the part is renamed.
    attribute :part_name, :string do
      public? true
      writable? false
      description "The part's name, frozen at work-order completion."
    end

    attribute :part_number, :string do
      public? true
      writable? false
      description "The part's number, frozen at work-order completion."
    end

    attribute :consume_stock?, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether completing the work order should draw this from inventory."
    end

    timestamps()
  end

  relationships do
    belongs_to :work_order_service_task, Fleetms.Maintenance.WorkOrderServiceTask do
      allow_nil? false
    end

    belongs_to :part, Fleetms.Inventory.Part do
      domain Fleetms.Inventory
      allow_nil? false
      public? true
    end

    belongs_to :inventory_location, Fleetms.Inventory.InventoryLocation do
      domain Fleetms.Inventory
      allow_nil? true
      public? true
    end
  end
end
