defmodule Fleetms.Billing.Invoice do
  @moduledoc """
  A bill issued to an organization for a subscription period (or a one-off). Carries
  its own `Money` totals and embedded line items, and moves `:draft → :open → :paid`
  (with `:void` / `:uncollectible` off-ramps) via `AshStateMachine`.

  Lives in the public schema; numbers are drawn from a global sequence.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Fleetms.Billing.Invoice.Changes.SetInvoiceNumber

  postgres do
    table "billing_invoices"
    repo Fleetms.Repo

    references do
      reference :organization, on_delete: :delete
      reference :subscription, on_delete: :nilify
    end

    custom_statements do
      statement :invoice_number_sequence do
        up "CREATE SEQUENCE IF NOT EXISTS billing_invoices_number_seq"
        down "DROP SEQUENCE IF EXISTS billing_invoices_number_seq"
      end
    end
  end

  state_machine do
    initial_states [:draft, :open]
    default_initial_state :draft
    state_attribute :status

    transitions do
      transition :open, from: [:draft], to: :open
      transition :mark_paid, from: [:open], to: :paid
      transition :void, from: [:draft, :open], to: :void
      transition :mark_uncollectible, from: [:open], to: :uncollectible
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

    create :create do
      description "Draft a new invoice with its line items and totals."
      primary? true

      accept [
        :organization_id,
        :subscription_id,
        :currency,
        :amount_due,
        :description,
        :line_items,
        :period_start,
        :period_end,
        :due_date
      ]

      change SetInvoiceNumber
    end

    update :open do
      description "Issue a draft invoice for collection."
      require_atomic? false
      change transition_state(:open)
      change set_attribute(:issued_at, &DateTime.utc_now/0)
    end

    update :mark_paid do
      description "Record the invoice as fully paid."
      require_atomic? false
      change transition_state(:paid)
      change set_attribute(:paid_at, &DateTime.utc_now/0)
      change atomic_update(:amount_paid, expr(amount_due))
    end

    update :void do
      change transition_state(:void)
    end

    update :mark_uncollectible do
      change transition_state(:uncollectible)
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

    attribute :number, :string do
      allow_nil? false
      public? true
      writable? false
      description "Human-readable sequential number, e.g. INV-000042."
    end

    attribute :status, Fleetms.Billing.InvoiceStatus do
      allow_nil? false
      public? true
      default :draft
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      default "ZMW"
      constraints match: ~r/^[A-Z]{3}$/
    end

    attribute :amount_due, AshMoney.Types.Money do
      allow_nil? false
      public? true
    end

    attribute :amount_paid, AshMoney.Types.Money do
      public? true
      description "Total paid so far; nil until any payment is recorded."
    end

    attribute :line_items, {:array, Fleetms.Billing.InvoiceLineItem} do
      public? true
      default []
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :period_start, :utc_datetime_usec, public?: true
    attribute :period_end, :utc_datetime_usec, public?: true
    attribute :due_date, :date, public?: true
    attribute :issued_at, :utc_datetime_usec, public?: true
    attribute :paid_at, :utc_datetime_usec, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, Fleetms.Accounts.Organization do
      allow_nil? false
      public? true
    end

    belongs_to :subscription, Fleetms.Billing.Subscription do
      public? true
    end

    has_many :payments, Fleetms.Billing.Payment
  end

  identities do
    identity :unique_number, [:number]
  end
end
