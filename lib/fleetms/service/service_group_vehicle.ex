defmodule Fleetms.Service.ServiceGroupVehicle do
  use Ash.Resource,
    domain: Fleetms.Service,
    data_layer: AshPostgres.DataLayer

  relationships do
    belongs_to :service_group, Fleetms.Service.ServiceGroup do
      domain Fleetms.Service
      destination_attribute :id
      primary_key? true
      allow_nil? false
    end

    belongs_to :vehicle, Fleetms.Vehicles.Vehicle do
      domain Fleetms.Vehicles
      destination_attribute :id
      primary_key? true
      allow_nil? false
    end
  end

  postgres do
    table "service_group_vehicles"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :service_group, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  multitenancy do
    strategy :context
  end
end
