defmodule Fleetms.VehicleInspection.InspectionFormVehicle do
  use Ash.Resource,
    domain: Fleetms.VehicleInspection,
    data_layer: AshPostgres.DataLayer

  relationships do
    belongs_to :inspection_form, Fleetms.VehicleInspection.InspectionForm do
      domain Fleetms.VehicleInspection
      destination_attribute :id
      primary_key? true
      allow_nil? false
    end

    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      domain Fleetms.VehicleManagement
      destination_attribute :id
      primary_key? true
      allow_nil? false
    end
  end

  postgres do
    table "inspection_form_vehicles"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :inspection_form, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  multitenancy do
    strategy :context
  end
end
