defmodule Fleetms.Billing.Plan do
  @moduledoc """
  A subscription plan the platform offers. Pricing supports both a flat `price`
  (a small-fleet / individual bundle) and an optional `price_per_vehicle` for
  usage-based plans; a subscription's `quantity` (vehicles) drives the per-vehicle
  portion. Prices are `Money` values in the plan's own currency (ZMW by default).

  Plans live in the public schema — they are platform-level catalogue records, not
  tenant data.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Fleetms.Billing.BillingInterval

  postgres do
    table "billing_plans"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :get_by_id do
      get_by :id
    end

    read :list_active do
      description "Active, publicly-offered plans, cheapest first."
      filter expr(active? == true and public? == true)
      prepare build(sort: [price: :asc])
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # The plan catalogue is readable by anyone; only staff (bypass above) write.
    policy action_type(:read) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :code, :string do
      allow_nil? false
      public? true
      description "Stable slug for the plan, e.g. \"starter\"."
      constraints match: ~r/^[a-z0-9][a-z0-9_-]*$/, max_length: 50
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :interval, BillingInterval do
      allow_nil? false
      public? true
      default :month
    end

    attribute :interval_count, :integer do
      allow_nil? false
      public? true
      default 1
      constraints min: 1, max: 36
      description "Number of intervals per billing period (e.g. 3 months)."
    end

    attribute :price, AshMoney.Types.Money do
      allow_nil? false
      public? true
      description "Flat base price per billing period."
    end

    attribute :price_per_vehicle, AshMoney.Types.Money do
      public? true
      description "Optional per-vehicle charge added on top of the base price."
    end

    attribute :included_vehicles, :integer do
      public? true
      constraints min: 0
      description "Vehicles covered by the base price before per-vehicle charges apply."
    end

    attribute :max_vehicles, :integer do
      public? true
      constraints min: 1
      description "Hard cap on vehicles for this plan, if any."
    end

    attribute :trial_days, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: 0, max: 365
    end

    attribute :active?, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether the plan can be subscribed to."
    end

    attribute :public?, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether the plan is shown in the self-serve catalogue."
    end

    timestamps()
  end

  relationships do
    has_many :subscriptions, Fleetms.Billing.Subscription
  end

  identities do
    identity :unique_code, [:code]
  end
end
