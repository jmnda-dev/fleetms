defmodule Fleetms.VehicleManagement.VehicleModel do
  @moduledoc """
  A model belonging to a `VehicleMake` (e.g. "Hilux" under "Toyota"), scoped to
  an organization. Like makes, models are created on demand from the vehicle
  form, so `create` upserts on `{name, make}`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "vehicle_models"
    repo Fleetms.Repo

    references do
      reference :vehicle_make, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, update: [:name]]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list_by_make do
      argument :vehicle_make_id, :uuid, allow_nil?: false
      filter expr(vehicle_make_id == ^arg(:vehicle_make_id))
      prepare build(sort: [name: :asc])
    end

    create :create do
      primary? true
      accept [:name, :vehicle_make_id]
      upsert? true
      upsert_identity :unique_name_per_make
      upsert_fields [:name]
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_vehicles)
    end

    policy action_type([:create, :update]) do
      authorize_if has_permission(:create_vehicle)
    end

    policy action_type(:destroy) do
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
      constraints min_length: 1, max_length: 50
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle_make, Fleetms.VehicleManagement.VehicleMake do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_name_per_make, [:name, :vehicle_make_id]
  end
end
