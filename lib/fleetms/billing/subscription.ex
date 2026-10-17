defmodule Fleetms.Billing.Subscription do
  @moduledoc """
  An organization's subscription to a `Plan`. This is the source of truth for an
  org's **entitlement**: `active_now?` is true while a paid (or trial) period is
  current, and the platform gates access on it.

  Lifecycle (`AshStateMachine` on `:status`):

      incomplete ──activate──▶ active ──renew──▶ active
           │                    │  ▲                │
           │                    │  └──activate──┐   │
           │              mark_past_due         │   │
           │                    ▼               │   │
           └── cancel ◀──── past_due ──activate─┘   │
                                │                    │
                              expire ◀───────────────┘

  Lives in the public schema (platform-level, keyed by `organization_id`).
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Fleetms.Billing.PaymentProviderType
  alias Fleetms.Billing.Subscription.Changes.AdvancePeriod

  postgres do
    table "billing_subscriptions"
    repo Fleetms.Repo

    references do
      reference :organization, on_delete: :delete
      reference :plan, on_delete: :nothing
    end
  end

  state_machine do
    initial_states [:incomplete]
    default_initial_state :incomplete
    state_attribute :status

    transitions do
      transition :activate, from: [:incomplete, :trialing, :past_due], to: :active
      transition :mark_past_due, from: [:trialing, :active], to: :past_due
      transition :cancel, from: [:incomplete, :trialing, :active, :past_due], to: :canceled
      transition :expire, from: [:trialing, :active, :past_due], to: :expired
    end
  end

  actions do
    defaults [:read, :destroy]

    read :get_by_id do
      get_by :id
    end

    read :list_for_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :list_past_period do
      description "Active subscriptions whose paid period has ended — due for dunning."
      argument :as_of, :utc_datetime_usec, allow_nil?: false

      filter expr(
               status == :active and not is_nil(current_period_end) and
                 current_period_end < ^arg(:as_of)
             )
    end

    read :list_past_due_before do
      description "Past-due subscriptions whose period ended before the grace cutoff — due to expire."
      argument :cutoff, :utc_datetime_usec, allow_nil?: false

      filter expr(
               status == :past_due and not is_nil(current_period_end) and
                 current_period_end < ^arg(:cutoff)
             )
    end

    create :subscribe do
      description "Create a subscription for an organization, awaiting first payment."
      primary? true
      accept [:organization_id, :plan_id, :quantity, :provider]
    end

    update :update do
      primary? true
      accept [:quantity, :provider, :cancel_at_period_end?]
    end

    update :activate do
      description "Mark paid and current, starting a fresh billing period from now."
      require_atomic? false
      change transition_state(:active)
      change {AdvancePeriod, from: :now}
      change set_attribute(:cancel_at_period_end?, false)
    end

    update :renew do
      description "Extend the current period by one plan interval (a successful renewal)."
      require_atomic? false
      validate attribute_equals(:status, :active), message: "only active subscriptions renew"
      change {AdvancePeriod, from: :period_end}
    end

    update :mark_past_due do
      description "A renewal payment failed; enter the grace/dunning state."
      change transition_state(:past_due)
    end

    update :cancel do
      require_atomic? false
      change transition_state(:canceled)
      change set_attribute(:canceled_at, &DateTime.utc_now/0)
    end

    update :expire do
      change transition_state(:expired)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(
                     exists(
                       organization.user_organizations,
                       user_id == ^actor(:id) and owner? == true
                     )
                   )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, Fleetms.Billing.SubscriptionStatus do
      allow_nil? false
      public? true
      default :incomplete
    end

    attribute :quantity, :integer do
      allow_nil? false
      public? true
      default 1
      constraints min: 1
      description "Vehicles/seats, driving any per-vehicle pricing."
    end

    attribute :current_period_start, :utc_datetime_usec, public?: true
    attribute :current_period_end, :utc_datetime_usec, public?: true
    attribute :trial_end, :utc_datetime_usec, public?: true
    attribute :started_at, :utc_datetime_usec, public?: true
    attribute :canceled_at, :utc_datetime_usec, public?: true

    attribute :cancel_at_period_end?, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :provider, PaymentProviderType do
      public? true
      description "The gateway used to pay for this subscription, once chosen."
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Fleetms.Accounts.Organization do
      allow_nil? false
      public? true
    end

    belongs_to :plan, Fleetms.Billing.Plan do
      allow_nil? false
      public? true
    end

    has_many :invoices, Fleetms.Billing.Invoice
    has_many :payments, Fleetms.Billing.Payment
  end

  calculations do
    calculate :active_now?,
              :boolean,
              expr(
                status in [:trialing, :active, :past_due] and
                  (is_nil(current_period_end) or current_period_end > now())
              ) do
      public? true
      description "Whether the org is currently entitled (period not yet ended)."
    end
  end
end
