defmodule Fleetms.Drivers.Driver do
  @moduledoc """
  A person who operates the fleet's vehicles but doesn't need an app login.

  Most drivers never sign in, so they're recorded here rather than as users:
  their name, contact details, and — importantly — their driving licence and its
  expiry, which surfaces on the calendar so nobody drives on an expired licence.
  Soft-deleted (AshArchival) like the other operational records.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Drivers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshArchival.Resource, AshJsonApi.Resource],
    # Owner-scopes drivers for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Drivers

  @writable_attrs [
    :first_name,
    :last_name,
    :status,
    :phone,
    :email,
    :license_number,
    :license_class,
    :license_expiry,
    :notes
  ]

  postgres do
    table "drivers"
    repo Fleetms.Repo
  end

  permissions do
    permission :view_drivers, action: :read, label: "View Drivers", group: "Drivers"
    permission :create_driver, action: :create, label: "Create Driver", group: "Drivers"
    permission :update_driver, action: :update, label: "Update Driver", group: "Drivers"
    permission :delete_driver, action: :destroy, label: "Delete Driver", group: "Drivers"
  end

  archive do
    exclude_read_actions([:list_archived])
  end

  json_api do
    type "driver"
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :last_name
        constraints one_of: [:last_name, :first_name, :license_expiry, :inserted_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare Drivers.Driver.Preparations.ListDrivers
    end

    read :list_archived do
      argument :search_query, :string, default: ""

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare Drivers.Driver.Preparations.ListDrivers
    end

    create :create do
      primary? true
      accept @writable_attrs
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs
    end

    update :restore do
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_drivers)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_driver)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_driver)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_driver)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :last_name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :status, Drivers.DriverStatus do
      allow_nil? false
      public? true
      default :active
    end

    attribute :phone, :string do
      public? true
      constraints max_length: 50
    end

    attribute :email, :string do
      public? true
      constraints max_length: 200
    end

    attribute :license_number, :string do
      public? true
      constraints max_length: 100
    end

    attribute :license_class, :string do
      public? true
      constraints max_length: 50
      description "Licence category, e.g. C1, HGV."
    end

    attribute :license_expiry, :date do
      public? true
      description "When the driving licence runs out."
    end

    attribute :notes, :string do
      public? true
      constraints max_length: 1000
    end

    timestamps()
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name)
  end
end
