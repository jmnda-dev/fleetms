defmodule Fleetms.VehicleManagement.Vehicle do
  @moduledoc """
  A vehicle in an organization's fleet — the core entity of the fleet domain.

  Carries general/identity information (name, plate, VIN, year, prices, mileage,
  status) and relates to a `VehicleModel` (which carries the make), an optional
  `VehicleGroup`, its `photos`/`documents`, and a `VehicleSpec` holding detailed
  mechanical specifications.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshPaperTrail.Resource, AshJsonApi.Resource],
    # Owner-scopes vehicles for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "vehicles"
    repo Fleetms.Repo

    references do
      reference :vehicle_model, on_delete: :nilify
      reference :vehicle_group, on_delete: :nilify
    end
  end

  alias Fleetms.VehicleManagement

  # Attributes accepted by both create and update.
  @writable_attrs [
    :name,
    :model_code,
    :category,
    :type,
    :body_style,
    :status,
    :chassis_number,
    :license_plate,
    :vin,
    :year,
    :color,
    :dealer_name,
    :base_price,
    :purchase_price,
    :purchase_date,
    :warranty_provider,
    :warranty_expiration_date,
    :warranty_notes,
    :mileage,
    :hours,
    :notes,
    :primary_image_key,
    :primary_thumbnail_key,
    :vehicle_model_id,
    :vehicle_group_id
  ]

  permissions do
    permission :view_vehicles,
      action: :read,
      label: "View Vehicles",
      group: "Vehicles"

    permission :create_vehicle,
      action: :create,
      label: "Create Vehicle",
      group: "Vehicles"

    permission :update_vehicle,
      action: [:update, :update_status],
      label: "Update Vehicle",
      group: "Vehicles"

    permission :delete_vehicle,
      action: :destroy,
      label: "Delete Vehicle",
      group: "Vehicles"
  end

  # Audit trail (AshPaperTrail): every create/update/destroy writes a `vehicles_versions`
  # row (in the tenant schema) with the acting user, the action name and a full diff —
  # status changes, edits, and so on. The History tab derives a timeline from these.
  paper_trail do
    change_tracking_mode(:full_diff)
    store_action_name?(true)
    reference_source?(false)
    ignore_attributes([:inserted_at, :updated_at])
    belongs_to_actor(:user, Fleetms.Accounts.User, domain: Fleetms.Accounts)
  end

  # Public REST (JSON:API) representation. Routes are declared on the domain.
  json_api do
    type "vehicle"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    # Vehicles offered in "assign a driver" pickers — only Active ones (you can't
    # assign a driver to a vehicle that isn't running).
    read :list_assignable do
      filter expr(status == :Active)
      prepare build(sort: [name: :asc])
    end

    # Vehicles offered in operational pickers (work orders, inspections, issues,
    # fuel, renewals) — everything except Sold/Disposed. In Shop / Out of Service /
    # Inactive vehicles still show (you might raise a work order to fix one, or an
    # inspection to check it). Vehicles with no status set are included.
    read :list_selectable do
      filter expr(is_nil(status) or status != :Sold)
      prepare build(sort: [name: :asc])
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :name
        constraints one_of: [:name, :year, :mileage, :status, :inserted_at, :updated_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare VehicleManagement.Vehicle.Preparations.ListVehicles
    end

    create :create do
      primary? true
      accept @writable_attrs
      argument :vehicle_spec, :map
      argument :tags, {:array, :string}

      change manage_relationship(:vehicle_spec, type: :direct_control)

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )

      change {VehicleManagement.Changes.SanitizeHtml, attributes: [:notes]}
    end

    update :update do
      primary? true
      require_atomic? false
      # Status is changed only through `:update_status` (the status modal), not the
      # full edit form.
      accept @writable_attrs -- [:status]
      argument :vehicle_spec, :map
      argument :tags, {:array, :string}

      validate VehicleManagement.Vehicle.Validations.MileageNotDecreasing
      change manage_relationship(:vehicle_spec, type: :direct_control)

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )

      change {VehicleManagement.Changes.SanitizeHtml, attributes: [:notes]}
    end

    # Change only the operational status (used by the status modal), separate from
    # the full edit form. Covered by the :update_vehicle permission.
    update :update_status do
      description "Change only the vehicle's operational status."
      # Non-atomic: writing an audit version (AshPaperTrail full_diff) can't be atomic.
      require_atomic? false
      accept [:status]
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change VehicleManagement.Vehicle.Changes.DeleteVehicleFiles
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_vehicles)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_vehicle)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_vehicle)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_vehicle)
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
      constraints min_length: 1, max_length: 30
    end

    attribute :model_code, :string do
      public? true
      constraints max_length: 30
    end

    attribute :category, VehicleManagement.VehicleCategory, public?: true
    attribute :type, VehicleManagement.VehicleType, allow_nil?: false, public?: true
    attribute :body_style, VehicleManagement.VehicleBodyStyle, public?: true

    attribute :status, VehicleManagement.VehicleStatus,
      public?: true,
      default: :Active

    attribute :chassis_number, :string do
      public? true
      constraints max_length: 30
    end

    attribute :license_plate, :string do
      public? true
      constraints max_length: 30
    end

    attribute :vin, :string do
      public? true
      constraints max_length: 30
    end

    attribute :year, :integer do
      public? true
      constraints min: 1900, max: 2100
    end

    attribute :color, :string do
      public? true
      constraints max_length: 30
    end

    attribute :dealer_name, :string do
      public? true
      constraints max_length: 500
    end

    attribute :base_price, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :purchase_price, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :purchase_date, :date, public?: true

    attribute :warranty_provider, :string do
      public? true
      constraints max_length: 200
      description "Who provides the warranty (manufacturer, dealer, third party)."
    end

    attribute :warranty_expiration_date, :date do
      public? true
      description "When the warranty runs out."
    end

    attribute :warranty_notes, :string do
      public? true
      constraints max_length: 1000
      description "Coverage details, claim contacts, etc."
    end

    attribute :mileage, :decimal do
      public? true
      default Decimal.new(0)
      allow_nil? false
      constraints min: 0, max: 999_999_999
    end

    attribute :hours, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :notes, :string do
      public? true
      description "Free-form rich-text notes (sanitized HTML from the editor)."
    end

    attribute :primary_image_key, :string do
      public? true
      description "Storage key for the headline photo shown in lists and the detail header."
    end

    attribute :primary_thumbnail_key, :string do
      public? true
      description "Storage key for the headline photo's thumbnail."
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle_model, Fleetms.VehicleManagement.VehicleModel do
      public? true
      attribute_writable? true
    end

    belongs_to :vehicle_group, Fleetms.VehicleManagement.VehicleGroup do
      public? true
      attribute_writable? true
    end

    has_one :vehicle_spec, Fleetms.VehicleManagement.VehicleSpec
    has_many :photos, Fleetms.VehicleManagement.VehiclePhoto
    has_many :documents, Fleetms.VehicleManagement.VehicleDocument

    many_to_many :tags, Fleetms.Tagging.Tag do
      domain Fleetms.Tagging
      through Fleetms.Tagging.Tagging
      source_attribute_on_join_resource :vehicle_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  calculations do
    # "Make Model - Name", collapsing to just the name when no model is set.
    # Make is reached through the model (a model always has a make).
    calculate :full_name,
              :string,
              expr(
                if is_nil(vehicle_model_id) do
                  name
                else
                  vehicle_model.vehicle_make.name <> " " <> vehicle_model.name <> " - " <> name
                end
              )
  end

  aggregates do
    count :photos_count, :photos
    count :documents_count, :documents
  end

  identities do
    identity :unique_name, [:name]
  end
end
