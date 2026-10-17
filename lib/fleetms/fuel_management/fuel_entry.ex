defmodule Fleetms.FuelManagement.FuelEntry do
  @moduledoc """
  A single refuel/recharge event for a vehicle: when it happened, the odometer at
  the time, how much fuel went in, and what it cost.

  Cost is a `Money` value that carries its own currency, so an org running across
  borders can log each fill-up in the currency it was actually paid in. The stored
  `odometer` is what later powers derived fuel-economy (distance since the previous
  fill-up ÷ quantity) — that reporting is a separate workstream; here we just
  capture accurate entries.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.FuelManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshArchival.Resource, AshJsonApi.Resource],
    # Owner-scopes fuel entries for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  # Soft delete (AshArchival): `destroy` archives instead of removing the row, so a
  # fuel entry deleted by mistake can be recovered. Archived rows are filtered out
  # of reads by AshArchival's default read preparation.

  alias Fleetms.FuelManagement

  @writable_attrs [
    :odometer,
    :refueled_at,
    :quantity,
    :cost,
    :location,
    :fuel_type,
    :payment_method,
    :notes,
    :receipt_image_key,
    :receipt_thumbnail_key,
    :vehicle_id,
    :refueled_by_id
  ]

  postgres do
    table "fuel_entries"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :refueled_by, on_delete: :nilify
    end
  end

  permissions do
    permission :view_fuel_entries,
      action: :read,
      label: "View Fuel Entries",
      group: "Fuel"

    permission :create_fuel_entry,
      action: :create,
      label: "Create Fuel Entry",
      group: "Fuel"

    permission :update_fuel_entry,
      action: :update,
      label: "Update Fuel Entry",
      group: "Fuel"

    permission :delete_fuel_entry,
      action: :destroy,
      label: "Delete Fuel Entry",
      group: "Fuel"
  end

  # Soft delete (AshArchival): `destroy` archives the entry. Fuel entries are current-
  # state operational data, so archiving hides them everywhere — every read is auto-
  # filtered. Only `:list_archived` (the archived view) opts out, applying its own
  # `not is_nil(archived_at)`.
  archive do
    exclude_read_actions([:list_archived])
  end

  json_api do
    type "fuel-entry"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :refueled_at
        constraints one_of: [:refueled_at, :odometer, :quantity, :inserted_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare FuelManagement.FuelEntry.Preparations.ListFuelEntries
    end

    # The mirror of `:list` for the archived view: only archived entries.
    read :list_archived do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :refueled_at
        constraints one_of: [:refueled_at, :odometer, :quantity, :inserted_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare FuelManagement.FuelEntry.Preparations.ListFuelEntries
    end

    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false
      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(sort: [refueled_at: :desc], load: [refueled_by: [:profile]])
    end

    create :create do
      primary? true
      accept @writable_attrs

      validate compare(:quantity, greater_than: 0) do
        message "must be greater than zero"
      end
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs

      validate compare(:quantity, greater_than: 0) do
        message "must be greater than zero"
      end
    end

    # Bring an archived fuel entry back into the active lists. Non-atomic: an atomic update
    # would re-read through the archival-filtered primary read and miss the archived row.
    update :restore do
      require_atomic? false
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
      authorize_if has_permission(:view_fuel_entries)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_fuel_entry)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_fuel_entry)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_fuel_entry)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :odometer, :decimal do
      allow_nil? false
      public? true
      constraints min: 0, max: 999_999_999
      description "Vehicle odometer reading at the time of refueling."
    end

    attribute :refueled_at, :utc_datetime do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
      description "When the refuel happened."
    end

    attribute :quantity, :decimal do
      allow_nil? false
      public? true
      constraints min: 0, max: 999_999_999
      description "Amount of fuel/energy added (litres, gallons, kWh — org's unit)."
    end

    attribute :cost, AshMoney.Types.Money do
      allow_nil? false
      public? true
      description "Total paid, in its own currency."
    end

    attribute :fuel_type, FuelManagement.FuelType do
      allow_nil? false
      public? true
      default :diesel
    end

    attribute :payment_method, FuelManagement.PaymentMethod do
      public? true
    end

    attribute :location, :string do
      public? true
      constraints max_length: 255
      description "Where the vehicle was refueled (station/site)."
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :receipt_image_key, :string do
      public? true
      description "Storage key for the uploaded receipt image (display size)."
    end

    attribute :receipt_thumbnail_key, :string do
      public? true
      description "Storage key for the receipt thumbnail."
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :refueled_by, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
      attribute_writable? true
      description "The member who refueled the vehicle, if recorded."
    end
  end
end
