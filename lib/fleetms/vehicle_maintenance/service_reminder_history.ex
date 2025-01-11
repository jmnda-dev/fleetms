defmodule Fleetms.VehicleMaintenance.ServiceReminderHistory do
  use Ash.Resource,
    domain: Fleetms.VehicleMaintenance,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :last_completed_mileage, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999_999
    end

    attribute :last_completed_hours, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999_999
    end

    attribute :last_completed_date, :date do
      allow_nil? true
      public? true
    end

    attribute :next_due_mileage, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :next_due_hours, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :next_due_date, :date do
      allow_nil? true
      public? true
    end

    attribute :vehicle_mileage, :decimal do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :work_order, Fleetms.VehicleMaintenance.WorkOrder do
      allow_nil? false
    end

    belongs_to :service_reminder, Fleetms.VehicleMaintenance.ServiceReminder do
      allow_nil? true
    end
  end

  actions do
    defaults [:read, update: :*]

    create :create do
      primary? true
      accept :*
      upsert? true
      upsert_fields :replace_all
      upsert_identity :unique_history

      argument :work_order_id, :uuid, allow_nil?: false
      argument :service_reminder_id, :uuid, allow_nil?: false

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)

      change manage_relationship(:service_reminder_id, :service_reminder,
               type: :append_and_remove
             )
    end
  end

  identities do
    identity :unique_history, [:service_reminder_id, :work_order_id]
  end

  postgres do
    table "service_reminder_histories"
    repo Fleetms.Repo

    references do
      reference :work_order, on_delete: :delete
      reference :service_reminder, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end
end
