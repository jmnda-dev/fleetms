defmodule Fleetms.Service.WorkOrderServiceTaskTechnicianLaborDetail do
  use Ash.Resource,
    domain: Fleetms.Service,
    data_layer: AshPostgres.DataLayer

  # TODO: Use Money type for some of these attributes
  attributes do
    uuid_primary_key :id

    attribute :hours, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      default 0
    end

    attribute :rate, AshMoney.Types.Money do
      allow_nil? true
      public? true
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

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :technician, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      source_attribute :technician_id
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :work_order_service_task, Fleetms.Service.WorkOrderServiceTask do
      destination_attribute :id
      allow_nil? false
    end
  end

  postgres do
    table "work_order_service_task_technician_labor_details"
    repo Fleetms.Repo

    references do
      reference :work_order_service_task, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      argument :work_order_service_task_id, :uuid

      argument :technician_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:work_order_service_task_id, :work_order_service_task,
               type: :append_and_remove
             )

      change manage_relationship(:technician_id, :technician, type: :append_and_remove)
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :work_order_service_task_id, :uuid

      argument :technician_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:work_order_service_task_id, :work_order_service_task,
               type: :append_and_remove
             )

      change manage_relationship(:technician_id, :technician, type: :append_and_remove)
    end
  end

  multitenancy do
    strategy :context
  end
end
