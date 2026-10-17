defmodule Fleetms.VehicleManagement.VehicleMake do
  @moduledoc """
  A vehicle manufacturer (e.g. "Toyota", "Volvo"), scoped to an organization.

  Makes are created on demand from the vehicle form's searchable/creatable
  select, so `upsert` is the primary create — typing a name that already exists
  relates to it rather than erroring.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "vehicle_makes"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, update: [:name]]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    create :create do
      primary? true
      accept [:name]
      upsert? true
      upsert_identity :unique_name
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
    has_many :vehicle_models, Fleetms.VehicleManagement.VehicleModel
  end

  identities do
    identity :unique_name, [:name]
  end
end
