defmodule Fleetms.Inventory.PartCategory do
  @moduledoc """
  A user-defined grouping for parts (e.g. "Filters", "Brakes", "Fluids"), scoped
  to an organization. Created on the fly from the part form (find-or-create by
  name), like renewal types and vehicle makes.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "part_categories"
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
      authorize_if has_permission(:view_parts)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_part)
    end

    policy action_type([:update, :destroy]) do
      authorize_if has_permission(:update_part)
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
    has_many :parts, Fleetms.Inventory.Part do
      destination_attribute :category_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
