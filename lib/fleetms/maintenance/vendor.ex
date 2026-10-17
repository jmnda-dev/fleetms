defmodule Fleetms.Maintenance.Vendor do
  @moduledoc """
  An outside supplier or repair shop the fleet does business with, scoped to an
  organization.

  Vendors are referenced by work orders when labour is outsourced (see
  `WorkOrderServiceTaskLaborItem`), and are a reusable contact record the expenses
  module will later draw on. This is a plain catalogue: name (unique) plus optional
  contact details.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshArchival.Resource, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "vendors"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where`).
    identity_wheres_to_sql unique_name: "archived_at IS NULL"
  end

  permissions do
    permission :view_vendors,
      action: :read,
      label: "View Vendors",
      group: "Maintenance"

    permission :create_vendor,
      action: :create,
      label: "Create Vendor",
      group: "Maintenance"

    permission :update_vendor,
      action: :update,
      label: "Update Vendor",
      group: "Maintenance"

    permission :delete_vendor,
      action: :destroy,
      label: "Delete Vendor",
      group: "Maintenance"
  end

  @writable_attrs [
    :name,
    :contact_name,
    :email,
    :phone,
    :website,
    :address,
    :notes
  ]

  # Soft delete (AshArchival), Option B: `destroy` archives instead of removing the
  # row. Archived vendors are hidden from the browse/pick list (see the filter on
  # `:list`), but stay resolvable where a completed work order already references
  # them, and via `get_by_id` — so history isn't broken. That's why the relationship
  # (`:read`) and detail (`:get_by_id`) reads are excluded from the archived filter;
  # only the browse `:list` action filters archived out.
  archive do
    # `:list_archived` shows only archived vendors, so it opts out of the automatic
    # `is_nil(archived_at)` filter and applies its own `not is_nil(archived_at)`.
    exclude_read_actions([:read, :get_by_id, :list_archived])
  end

  json_api do
    type "vendor"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list do
      argument :search_query, :string, default: ""

      argument :sort_by, :atom do
        constraints one_of: [:name, :contact_name, :inserted_at]
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

      # Browse/pick list hides archived vendors (Option B — see the archive block).
      filter expr(is_nil(archived_at))
      prepare Fleetms.Maintenance.Vendor.Preparations.ListVendors
    end

    # The mirror of `:list` for the archived view: only archived vendors.
    read :list_archived do
      argument :search_query, :string, default: ""

      argument :sort_by, :atom do
        constraints one_of: [:name, :contact_name, :inserted_at]
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
      prepare Fleetms.Maintenance.Vendor.Preparations.ListVendors
    end

    create :create do
      primary? true
      accept @writable_attrs
    end

    update :update do
      primary? true
      accept @writable_attrs
    end

    # Bring an archived vendor back. If a live vendor now holds the same name, the
    # partial unique index rejects the restore — the caller surfaces that as a message.
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
      authorize_if has_permission(:view_vendors)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_vendor)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_vendor)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_vendor)
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
      constraints min_length: 1, max_length: 150
    end

    attribute :contact_name, :string do
      public? true
      constraints max_length: 150
    end

    attribute :email, :string do
      public? true
      constraints max_length: 150
    end

    attribute :phone, :string do
      public? true
      constraints max_length: 50
    end

    attribute :website, :string do
      public? true
      constraints max_length: 200
    end

    attribute :address, :string do
      public? true
      constraints max_length: 500
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    has_many :labor_items, Fleetms.Maintenance.WorkOrderServiceTaskLaborItem do
      destination_attribute :vendor_id
    end
  end

  identities do
    # Partial unique index: names are unique only among non-archived vendors, so a
    # name freed by archiving can be reused.
    identity :unique_name, [:name] do
      where expr(is_nil(archived_at))
    end
  end
end
