defmodule Fleetms.Service.WorkOrderServiceTask do
  use Ash.Resource,
    domain: Fleetms.Service,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  attributes do
    uuid_primary_key :id
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :work_order, Fleetms.Service.WorkOrder do
      destination_attribute :id
      allow_nil? false
    end

    belongs_to :service_task, Fleetms.Service.ServiceTask do
      destination_attribute :id
      allow_nil? false
    end

    has_many :work_order_service_task_parts, Fleetms.Service.WorkOrderServiceTaskPart do
      source_attribute :id
      destination_attribute :work_order_service_task_id
    end

    has_many :work_order_service_task_vendor_labor_details,
             Fleetms.Service.WorkOrderServiceTaskVendorLaborDetail do
      source_attribute :id
      destination_attribute :work_order_service_task_id
    end

    has_many :work_order_service_task_technician_labor_details,
             Fleetms.Service.WorkOrderServiceTaskTechnicianLaborDetail do
      source_attribute :id
      destination_attribute :work_order_service_task_id
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action([:create, :update, :destroy]) do
      authorize_if accessing_from(Fleetms.Service.WorkOrder, :work_order_service_tasks)
    end
  end

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

    read :read_for_form do
      primary? true
      prepare build(load: [:service_task_name, :service_task, :service_reminder])
    end

    create :create do
      primary? true
      accept :*
      argument :work_order_id, :uuid

      argument :service_task_id, :uuid do
        allow_nil? false
      end

      argument :sevice_task_name, :string
      argument :service_group_name, :string
      argument :mileage_interval, :decimal
      argument :time_interval, :integer
      argument :time_interval_unit, :atom
      argument :is_from_reminder, :boolean

      argument :work_order_service_task_parts, {:array, :map}
      argument :work_order_service_task_vendor_labor_details, {:array, :map}
      argument :work_order_service_task_technician_labor_details, {:array, :map}

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)
      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)

      change manage_relationship(:work_order_service_task_parts, :work_order_service_task_parts,
               type: :direct_control
             )

      change manage_relationship(
               :work_order_service_task_vendor_labor_details,
               :work_order_service_task_vendor_labor_details,
               type: :direct_control
             )

      change manage_relationship(
               :work_order_service_task_technician_labor_details,
               :work_order_service_task_technician_labor_details,
               type: :direct_control
             )
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*
      argument :work_order_id, :uuid

      argument :service_task_id, :uuid

      argument :sevice_task_name, :string
      argument :service_group_name, :string
      argument :mileage_interval, :decimal
      argument :time_interval, :integer
      argument :time_interval_unit, :atom
      argument :is_from_reminder, :boolean
      argument :work_order_service_task_parts, {:array, :map}
      argument :work_order_service_task_vendor_labor_details, {:array, :map}
      argument :work_order_service_task_technician_labor_details, {:array, :map}

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)
      # change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)

      change manage_relationship(:work_order_service_task_parts, :work_order_service_task_parts,
               type: :direct_control
             )

      change manage_relationship(
               :work_order_service_task_vendor_labor_details,
               :work_order_service_task_vendor_labor_details,
               type: :direct_control
             )

      change manage_relationship(
               :work_order_service_task_technician_labor_details,
               :work_order_service_task_technician_labor_details,
               type: :direct_control
             )
    end
  end

  aggregates do
    first :service_task_name, :service_task, :name
    count :total_parts, :work_order_service_task_parts

    sum :total_cost_parts, :work_order_service_task_parts, :subtotal do
      default "0.0"
    end

    sum :total_cost_labor, :work_order_service_task_technician_labor_details, :subtotal do
      default "0.0"
    end
  end

  calculations do
    calculate :service_reminder,
              :map,
              Fleetms.Service.Calculations.WorkOrderServiceTaskVehicleReminder
  end

  multitenancy do
    strategy :context
  end
end
