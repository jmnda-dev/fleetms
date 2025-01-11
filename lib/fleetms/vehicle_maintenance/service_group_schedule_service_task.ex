defmodule Fleetms.VehicleMaintenance.ServiceGroupScheduleServiceTask do
  use Ash.Resource,
    domain: Fleetms.VehicleMaintenance,
    data_layer: AshPostgres.DataLayer

  relationships do
    belongs_to :service_group_schedule, Fleetms.VehicleMaintenance.ServiceGroupSchedule do
      destination_attribute :id
      allow_nil? false
      primary_key? true
    end

    belongs_to :service_task, Fleetms.VehicleMaintenance.ServiceTask do
      destination_attribute :id
      allow_nil? false
      primary_key? true
    end
  end

  postgres do
    table "service_group_schedule_service_tasks"
    repo Fleetms.Repo

    references do
      reference :service_group_schedule, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  multitenancy do
    strategy :context
  end
end
