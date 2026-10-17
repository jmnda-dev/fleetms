defmodule Fleetms.VehicleManagement.RenewalType do
  @moduledoc """
  A user-defined kind of vehicle renewal (e.g. "Insurance", "Roadworthiness",
  "Registration"), scoped to an organization. Created on the fly from the renewal
  form (find-or-create by name), like vehicle makes and groups.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "renewal_types"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, update: [:name, :description]]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    create :create do
      primary? true
      accept [:name, :description]
      upsert? true
      upsert_identity :unique_name
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_renewals)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_renewal)
    end

    policy action_type([:update, :destroy]) do
      authorize_if has_permission(:update_renewal)
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
    has_many :vehicle_renewals, Fleetms.VehicleManagement.VehicleRenewal
  end

  identities do
    identity :unique_name, [:name]
  end
end
