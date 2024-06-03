defmodule Fleetms.Vehicles.Vehicle do
  @moduledoc """
  A Vehicle resource
  """
  use Ash.Resource,
    domain: Fleetms.Vehicles,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager, IsTechnician}

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 0, max_length: 50
    end

    attribute :category, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.vehicle_categories()
    end

    attribute :type, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.vehicle_types()
    end

    attribute :body_style, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.vehicle_body_styles()
    end

    attribute :license_plate, :string do
      allow_nil? true
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :vin, :string do
      allow_nil? true
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :year, :integer do
      public? true
      allow_nil? true
      constraints min: 1950
    end

    attribute :purchase_date, :date do
      allow_nil? true
      public? true
    end

    # TODO: Maybe use Money
    attribute :purchase_price, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :color, :string do
      allow_nil? true
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :photo, :string do
      allow_nil? true
      public? true
      writable? false
    end

    attribute :mileage_in_distance, :decimal do
      allow_nil? true
      public? true
      default 0
      constraints min: 0, max: 999_999_999
    end

    # TODO: Add attribute to for vehicle mileage in hours
    # TODO: Add more vehicle attributes, perhaps a dynamic form/JSON Schema implementation where users can add there own fields

    attribute :status, :atom do
      public? true
      allow_nil? false
      constraints one_of: Fleetms.Enums.vehicle_statuses()
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle_model, Fleetms.Vehicles.VehicleModel do
      allow_nil? true
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass IsAdmin do
      authorize_if always()
    end

    policy action(:list) do
      authorize_if IsFleetManager
      authorize_if IsTechnician
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:*]

      argument :vehicle_model, :map, allow_nil?: false

      change manage_relationship(:vehicle_model,
               identity_priority: [:unique_name],
               use_identities: [:unique_name],
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               on_missing: :destroy
             )
    end

    update :update do
      primary? true
      accept [:*]
      require_atomic? false

      argument :vehicle_model, :map

      change manage_relationship(:vehicle_model,
               identity_priority: [:unique_name],
               use_identities: [:unique_name],
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               on_missing: :destroy
             )
    end

    read :list
  end

  identities do
    identity :unique_name, [:name]
  end

  postgres do
    table "vehicles"
    repo Fleetms.Repo

    references do
      # TODO: This is not a best idea, will leave it here for now.
      reference :vehicle_model, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
