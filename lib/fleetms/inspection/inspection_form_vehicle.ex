defmodule Fleetms.Inspection.InspectionFormVehicle do
  use Ash.Resource,
    domain: Fleetms.Inspection,
    data_layer: AshPostgres.DataLayer

  relationships do
    belongs_to :inspection_form, Fleetms.Inspection.InspectionForm do
      domain Fleetms.Inspection
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
