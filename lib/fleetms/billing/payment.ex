defmodule Fleetms.Billing.Payment do
  @moduledoc """
  A single collection attempt against an invoice (or standalone), through one
  provider. Holds everything needed to hand the customer off and reconcile the
  result: our own `reference` (idempotency key), the provider's `provider_reference`,
  the `checkout_url` (redirect providers like DPO) or `instructions` (pay-in
  providers like Lenco), and snapshots of the raw request/response for audit.

  Moves `:pending → :processing → :succeeded` (or `:failed`/`:canceled`/`:expired`)
  via `AshStateMachine`. The provider adapters (a later change) drive these
  transitions from webhooks and status checks. Lives in the public schema.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Fleetms.Billing.{PaymentMethod, PaymentProviderType}
  alias Fleetms.Billing.Payment.Changes.SetReference

  postgres do
    table "billing_payments"
    repo Fleetms.Repo

    references do
      reference :organization, on_delete: :delete
      reference :invoice, on_delete: :nilify
      reference :subscription, on_delete: :nilify
    end
  end

  state_machine do
    initial_states [:pending]
    default_initial_state :pending
    state_attribute :status

    transitions do
      transition :start_processing, from: [:pending], to: :processing
      transition :succeed, from: [:pending, :processing], to: :succeeded
      transition :fail, from: [:pending, :processing], to: :failed
      transition :cancel, from: [:pending, :processing], to: :canceled
      transition :expire, from: [:pending, :processing], to: :expired
    end
  end

  actions do
    defaults [:read, :destroy]

    read :get_by_id do
      get_by :id
    end

    read :get_by_reference do
      get_by :reference
    end

    read :list_for_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter expr(organization_id == ^arg(:organization_id))
      prepare build(sort: [inserted_at: :desc])
    end

    create :create do
      description "Start a payment attempt (before handing off to the provider)."
      primary? true

      accept [
        :organization_id,
        :invoice_id,
        :subscription_id,
        :provider,
        :method,
        :amount,
        :customer_name,
        :customer_email,
        :customer_phone
      ]

      change SetReference
    end

    update :start_processing do
      description "Record the provider handoff (checkout URL or pay-in instructions)."
      require_atomic? false

      accept [
        :provider_reference,
        :checkout_url,
        :instructions,
        :method,
        :raw_request,
        :raw_response
      ]

      change transition_state(:processing)
    end

    update :succeed do
      description "Confirm the payment as settled."
      require_atomic? false
      accept [:provider_reference, :method, :raw_response]
      change transition_state(:succeeded)
      change set_attribute(:paid_at, &DateTime.utc_now/0)
    end

    update :fail do
      require_atomic? false
      accept [:failure_reason, :raw_response]
      change transition_state(:failed)
    end

    update :cancel do
      change transition_state(:canceled)
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

    attribute :reference, :string do
      allow_nil? false
      public? true
      writable? false
      description "Our idempotency key, matched against webhooks/verifications."
    end

    attribute :provider, PaymentProviderType do
      allow_nil? false
      public? true
    end

    attribute :method, PaymentMethod, public?: true

    attribute :status, Fleetms.Billing.PaymentStatus do
      allow_nil? false
      public? true
      default :pending
    end

    attribute :amount, AshMoney.Types.Money do
      allow_nil? false
      public? true
    end

    attribute :provider_reference, :string do
      public? true
      description "The provider's own transaction id/token."
    end

    attribute :checkout_url, :string do
      public? true
      description "Hosted-checkout URL to redirect the customer to (redirect providers)."
    end

    attribute :instructions, :map do
      public? true
      description "Pay-in details to display to the customer (pay-in providers)."
    end

    attribute :customer_name, :string, public?: true
    attribute :customer_email, :string, public?: true
    attribute :customer_phone, :string, public?: true
    attribute :failure_reason, :string, public?: true

    attribute :raw_request, :map,
      description: "Snapshot of the request we sent the provider (audit)."

    attribute :raw_response, :map,
      description: "Snapshot of the provider's response/webhook (audit)."

    attribute :paid_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, Fleetms.Accounts.Organization do
      allow_nil? false
      public? true
    end

    belongs_to :invoice, Fleetms.Billing.Invoice, public?: true
    belongs_to :subscription, Fleetms.Billing.Subscription, public?: true
  end

  identities do
    identity :unique_reference, [:reference]
  end
end
