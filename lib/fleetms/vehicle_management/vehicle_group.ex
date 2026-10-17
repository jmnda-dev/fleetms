defmodule Fleetms.VehicleManagement.VehicleGroup do
  @moduledoc """
  A user-defined grouping of vehicles (e.g. "North Depot", "Delivery Fleet"),
  scoped to an organization.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshArchival.Resource, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "vehicle_groups"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where`).
    identity_wheres_to_sql unique_name: "archived_at IS NULL"
  end

  json_api do
    type "vehicle-group"
  end

  # Soft delete (AshArchival): `destroy` archives the group. A group is current-state
  # config (not historical), and a vehicle's group is optional, so archiving simply
  # hides it everywhere — from the group list/picker and from any vehicle that was in
  # it (that vehicle just shows no group). No archive block needed: the default read
  # preparation filters archived rows out of every read.

  actions do
    defaults [:read, :destroy, create: [:name, :description], update: [:name, :description]]
    default_accept []

    read :get_by_id do
      get_by :id
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_vehicles)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_vehicle)
    end

    policy action_type([:update, :destroy]) do
      authorize_if has_permission(:update_vehicle)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    timestamps()
  end

  relationships do
    has_many :vehicles, Fleetms.VehicleManagement.Vehicle
  end

  identities do
    # Partial index: names are unique only among non-archived groups.
    identity :unique_name, [:name] do
      where expr(is_nil(archived_at))
    end
  end
end
