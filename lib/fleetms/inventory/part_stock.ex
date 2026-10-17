defmodule Fleetms.Inventory.PartStock do
  @moduledoc """
  The quantity of a given `Part` held at a given `InventoryLocation` — the source
  of truth for stock. A part's total on-hand is the sum of its `PartStock` rows.

  Quantity is set directly (create/update) or moved with the atomic `adjust`
  action (positive delta to receive, negative to consume — this is the seam work
  orders will consume parts through). A `quantity >= 0` check constraint means a
  consume can't take a location's stock below zero.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "part_stocks"
    repo Fleetms.Repo

    references do
      reference :part, on_delete: :delete
      reference :inventory_location, on_delete: :delete
    end

    check_constraints do
      check_constraint :quantity, "part_stocks_quantity_non_negative",
        check: "quantity >= 0",
        message: "would take stock below zero"
    end
  end

  json_api do
    type "part-stock"
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list_by_part do
      argument :part_id, :uuid, allow_nil?: false
      filter expr(part_id == ^arg(:part_id))
      prepare build(load: [:inventory_location], sort: [location_name: :asc])
    end

    create :create do
      primary? true
      accept [:part_id, :inventory_location_id, :quantity]
      upsert? true
      upsert_identity :unique_part_location
    end

    update :update do
      primary? true
      accept [:quantity]
    end

    update :adjust do
      description "Receive (positive) or consume (negative) at this location, atomically."
      argument :delta, :decimal, allow_nil?: false

      change atomic_update(:quantity, expr(quantity + ^arg(:delta)))
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_parts)
    end

    # Stock is part of managing a part; either create or update on parts qualifies.
    policy action_type([:create, :update, :destroy]) do
      authorize_if has_permission(:create_part)
      authorize_if has_permission(:update_part)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      default Decimal.new(0)
      constraints min: 0, max: 9_999_999_999
    end

    timestamps()
  end

  relationships do
    belongs_to :part, Fleetms.Inventory.Part do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :inventory_location, Fleetms.Inventory.InventoryLocation do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  aggregates do
    first :location_name, :inventory_location, :name
  end

  identities do
    identity :unique_part_location, [:part_id, :inventory_location_id]
  end
end
