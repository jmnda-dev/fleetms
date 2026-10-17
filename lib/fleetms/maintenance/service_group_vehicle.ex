defmodule Fleetms.Maintenance.ServiceGroupVehicle do
  @moduledoc """
  Join between a service group and a vehicle it applies to. Membership is managed
  through the group; adding/removing a vehicle drives the reminder fan-out.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "service_group_vehicles"
    repo Fleetms.Repo

    references do
      reference :service_group, on_delete: :delete
      reference :vehicle, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if accessing_from(Fleetms.Maintenance.ServiceGroup, :service_group_vehicles)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :service_group, Fleetms.Maintenance.ServiceGroup do
      primary_key? false
      allow_nil? false
    end

    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      primary_key? false
      allow_nil? false
    end
  end

  identities do
    identity :unique_group_vehicle, [:service_group_id, :vehicle_id]
  end
end
