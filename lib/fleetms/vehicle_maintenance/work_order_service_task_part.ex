defmodule Fleetms.VehicleMaintenance.WorkOrderServiceTaskPart do
  use Ash.Resource,
    domain: Fleetms.VehicleMaintenance,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :unit_cost, AshMoney.Types.Money do
      allow_nil? true
      public? true
    end

    attribute :quantity, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :subtotal, AshMoney.Types.Money do
      allow_nil? true
      public? true
    end

    attribute :comments, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 500
    end

    attribute :update_inventory, :boolean do
      allow_nil? false
      public? true
      default false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :work_order_service_task, Fleetms.VehicleMaintenance.WorkOrderServiceTask do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :part, Fleetms.Inventory.Part do
      domain Fleetms.Inventory
      allow_nil? false
    end

    belongs_to :inventory_location, Fleetms.Inventory.InventoryLocation do
      domain Fleetms.Inventory
      allow_nil? true
    end
  end

  postgres do
    table "work_order_service_task_parts"
    repo Fleetms.Repo

    references do
      reference :work_order_service_task, on_delete: :delete
      reference :part, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*
      argument :work_order_service_task_id, :uuid

      argument :part_id, :uuid do
        allow_nil? false
      end

      argument :inventory_location_id, :uuid do
        allow_nil? true
      end

      change manage_relationship(:work_order_service_task_id, :work_order_service_task,
               type: :append_and_remove
             )

      change manage_relationship(:part_id, :part, type: :append_and_remove)

      change manage_relationship(:inventory_location_id, :inventory_location,
               type: :append_and_remove
             )

      change &calculate_subtotal/2
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*
      argument :work_order_service_task_id, :uuid

      argument :part_id, :uuid do
        allow_nil? false
      end

      argument :inventory_location_id, :uuid do
        allow_nil? true
      end

      change manage_relationship(:work_order_service_task_id, :work_order_service_task,
               type: :append_and_remove
             )

      change manage_relationship(:part_id, :part, type: :append_and_remove)

      change manage_relationship(:inventory_location_id, :inventory_location,
               type: :append_and_remove
             )

      change &calculate_subtotal/2
    end
  end

  multitenancy do
    strategy :context
  end

  defp calculate_subtotal(changeset, _context) do
    unit_cost = Ash.Changeset.get_attribute(changeset, :unit_cost)
    quantity = Ash.Changeset.get_attribute(changeset, :quantity)

    if changeset.valid? and not is_nil(unit_cost) and not is_nil(quantity) do
      Ash.Changeset.change_attribute(changeset, :subtotal, Money.mult!(unit_cost, quantity))
    else
      changeset
    end
  end
end
