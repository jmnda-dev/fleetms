defmodule Fleetms.Inventory.Part do
  @moduledoc """
  A stocked or catalogued part — the inventory items a fleet keeps to service its
  vehicles (filters, fluids, brake pads, …). The entry point for the Inventory
  module and, later, what work orders consume.

  Stock is held per location: each `PartStock` row is the quantity of this part at
  one `InventoryLocation`, and the part's `total_stock` is the derived sum across
  them. Parts opt into tracking with `track_inventory`; a derived `stock_status`
  ("In stock" / "Low" / "Out of stock" / "Not tracked") compares `total_stock`
  against `quantity_threshold`. Quantities are changed on the `PartStock` rows
  (see `Fleetms.Inventory.PartStock`), not here.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshArchival.Resource, AshOban, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Inventory

  @writable_attrs [
    :part_number,
    :name,
    :description,
    :oem_part_number,
    :unit_cost,
    :unit_measurement,
    :manufacturer,
    :track_inventory,
    :quantity_threshold,
    :category_id
  ]

  postgres do
    table "parts"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where`).
    identity_wheres_to_sql unique_part_number: "archived_at IS NULL"

    references do
      reference :category, on_delete: :nilify
    end
  end

  permissions do
    permission :view_parts,
      action: :read,
      label: "View Parts",
      group: "Inventory"

    permission :create_part,
      action: :create,
      label: "Create Part",
      group: "Inventory"

    permission :update_part,
      action: :update,
      label: "Update Part",
      group: "Inventory"

    permission :delete_part,
      action: :destroy,
      label: "Delete Part",
      group: "Inventory"
  end

  # Soft delete (AshArchival), Option B: `destroy` archives the part. Archived parts
  # are hidden from the browse/pick list (see the filter on `:list`), but still
  # resolve where a completed work order's line item references one, and via
  # `get_by_id` — so cost history keeps its part. Only `:list` filters archived out;
  # the relationship (`:read`) and detail (`:get_by_id`) reads are excluded.
  archive do
    # `:list_archived` shows only archived parts, so it opts out of the automatic
    # `is_nil(archived_at)` filter and applies its own `not is_nil(archived_at)`.
    exclude_read_actions([:read, :get_by_id, :list_archived])
  end

  oban do
    # Run scheduled actions once per organization (see the reminder digest).
    list_tenants fn -> Fleetms.Repo.all_tenants() end

    scheduled_actions do
      # Every morning, email each org's owner(s) the parts that are low or out of
      # stock. Stock status is derived live; the job only notifies.
      schedule :daily_low_stock_digest, "0 7 * * *" do
        action :send_low_stock_digest
        queue :low_stock_digest
        worker_module_name Fleetms.Inventory.Part.Workers.DailyLowStockDigest
      end
    end
  end

  json_api do
    type "part"
  end

  actions do
    defaults [:read]
    default_accept []

    # Run per organization by AshOban: email the owner(s) a digest of the org's
    # low / out-of-stock parts. Returns the number of recipients emailed.
    action :send_low_stock_digest, :integer do
      run fn _input, context ->
        Fleetms.Inventory.LowStockDigest.deliver_for_tenant(context.tenant)
      end
    end

    read :get_by_id do
      get_by :id
      prepare build(load: [:stock_status, :total_stock, :category])
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :part_number
        constraints one_of: [:part_number, :name, :total_stock, :inserted_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      # Browse/pick list hides archived parts (Option B — see the archive block).
      filter expr(is_nil(archived_at))
      prepare Inventory.Part.Preparations.ListParts
    end

    # The mirror of `:list` for the archived view: only archived parts. Reuses the same
    # search/sort/load preparation as `:list`.
    read :list_archived do
      argument :search_query, :string, default: ""

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare Inventory.Part.Preparations.ListParts
    end

    create :create do
      primary? true
      accept @writable_attrs
      argument :tags, {:array, :string}

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )
    end

    update :update do
      primary? true
      # manage_relationship for tags can't run atomically.
      require_atomic? false
      accept @writable_attrs
      argument :tags, {:array, :string}

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )
    end

    # Bring an archived part back into the catalogue. Gated by `update_part` (it's an
    # update). If a live part now holds the same part number, the partial unique index
    # rejects the restore — the caller surfaces that as a friendly message.
    update :restore do
      change set_attribute(:archived_at, nil)
    end

    destroy :destroy do
      primary? true
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

    policy action_type(:update) do
      authorize_if has_permission(:update_part)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_part)
    end

    # Internal notifier action, invoked only by the AshOban scheduled job (no actor);
    # it reads with authorize?: false and only emails the org owner.
    policy action(:send_low_stock_digest) do
      authorize_if always()
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :part_number, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
      description "The organization's identifier for the part."
    end

    attribute :name, :string do
      public? true
      constraints max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :oem_part_number, :string do
      public? true
      constraints max_length: 100
      description "The manufacturer's original part number, if different."
    end

    attribute :unit_cost, AshMoney.Types.Money do
      public? true
      description "What one unit costs, in its own currency."
    end

    attribute :unit_measurement, :string do
      public? true
      constraints max_length: 50
      description "How the part is counted (each, litre, metre, …)."
    end

    attribute :manufacturer, :string do
      public? true
      constraints max_length: 100
    end

    attribute :track_inventory, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether stock levels are tracked and flagged against the threshold."
    end

    attribute :quantity_threshold, :decimal do
      allow_nil? false
      public? true
      default Decimal.new(0)
      constraints min: 0, max: 9_999_999_999
      description "Reorder point: at or below this, tracked stock reads \"Low\"."
    end

    timestamps()
  end

  relationships do
    belongs_to :category, Fleetms.Inventory.PartCategory do
      public? true
      attribute_writable? true
    end

    has_many :part_stocks, Fleetms.Inventory.PartStock

    many_to_many :tags, Fleetms.Tagging.Tag do
      domain Fleetms.Tagging
      through Fleetms.Tagging.Tagging
      source_attribute_on_join_resource :part_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  calculations do
    calculate :stock_status,
              :string,
              expr(
                cond do
                  not track_inventory -> "Not tracked"
                  total_stock <= 0 -> "Out of stock"
                  total_stock <= quantity_threshold -> "Low"
                  true -> "In stock"
                end
              )
  end

  aggregates do
    # Total on-hand across every location; 0 when the part is stocked nowhere.
    sum :total_stock, :part_stocks, :quantity do
      default Decimal.new(0)
    end
  end

  identities do
    # Partial index: part numbers are unique only among non-archived parts.
    identity :unique_part_number, [:part_number] do
      where expr(is_nil(archived_at))
    end
  end
end
