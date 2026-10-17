defmodule Fleetms.Inventory.InventoryLocation do
  @moduledoc """
  A place where parts are stored — a warehouse, store room, service van, etc.,
  scoped to an organization. A part's stock is held per location via `PartStock`,
  and the part's total on-hand is the sum across its locations.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshArchival.Resource, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "inventory_locations"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where`).
    identity_wheres_to_sql unique_name: "archived_at IS NULL"
  end

  permissions do
    permission :view_inventory_locations,
      action: :read,
      label: "View Inventory Locations",
      group: "Inventory"

    permission :create_inventory_location,
      action: :create,
      label: "Create Inventory Location",
      group: "Inventory"

    permission :update_inventory_location,
      action: :update,
      label: "Update Inventory Location",
      group: "Inventory"

    permission :delete_inventory_location,
      action: :destroy,
      label: "Delete Inventory Location",
      group: "Inventory"
  end

  # Soft delete (AshArchival), Option B: `destroy` archives the location. Archived
  # locations are hidden from the browse/pick list (see the filter on `:list`), but
  # still resolve where a part's stock row references one — via the relationship
  # (`:read`) and detail (`:get_by_id`) — so stock keeps its location.
  archive do
    # `:list_archived` shows only archived locations, so it opts out of the automatic
    # `is_nil(archived_at)` filter and applies its own `not is_nil(archived_at)`.
    exclude_read_actions([:read, :get_by_id, :list_archived])
  end

  json_api do
    type "inventory-location"
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    read :get_by_id do
      get_by :id
      prepare build(load: [:part_count])
    end

    read :list do
      argument :search_query, :string, default: ""

      argument :sort_by, :atom do
        constraints one_of: [:name, :part_count, :inserted_at]
        default :name
      end

      argument :sort_order, :atom do
        constraints one_of: [:asc, :desc]
        default :asc
      end

      pagination offset?: true,
                 countable: true,
                 default_limit: 20,
                 max_page_size: 100,
                 required?: false

      # Browse/pick list hides archived locations (Option B — see the archive block).
      filter expr(is_nil(archived_at))
      prepare Fleetms.Inventory.InventoryLocation.Preparations.ListLocations
    end

    # The mirror of `:list` for the archived view: only archived locations.
    read :list_archived do
      argument :search_query, :string, default: ""

      argument :sort_by, :atom do
        constraints one_of: [:name, :part_count, :inserted_at]
        default :name
      end

      argument :sort_order, :atom do
        constraints one_of: [:asc, :desc]
        default :asc
      end

      pagination offset?: true,
                 countable: true,
                 default_limit: 20,
                 max_page_size: 100,
                 required?: false

      filter expr(not is_nil(archived_at))
      prepare Fleetms.Inventory.InventoryLocation.Preparations.ListLocations
    end

    create :create do
      primary? true
      accept [:name, :description]
    end

    update :update do
      primary? true
      accept [:name, :description]
    end

    # Bring an archived location back. If a live location now holds the same name, the
    # partial unique index rejects the restore — the caller surfaces that as a message.
    update :restore do
      change set_attribute(:archived_at, nil)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # Parts manage their stock rows through the location relationship.
    policy action_type(:read) do
      authorize_if has_permission(:view_inventory_locations)
      authorize_if has_permission(:view_parts)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_inventory_location)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_inventory_location)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_inventory_location)
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
    has_many :part_stocks, Fleetms.Inventory.PartStock
  end

  aggregates do
    count :part_count, :part_stocks
  end

  identities do
    # Partial index: names are unique only among non-archived locations.
    identity :unique_name, [:name] do
      where expr(is_nil(archived_at))
    end
  end
end
