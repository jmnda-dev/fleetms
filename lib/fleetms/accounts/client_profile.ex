defmodule Fleetms.Accounts.ClientProfile do
  @moduledoc """
  Know-your-customer / onboarding details for a managed-service client.

  Public-schema (non-tenant): it belongs to an `Organization` and holds the
  contact and verification information platform staff collect when provisioning
  a client. One profile per organization. Only ever readable/writable by
  platform staff (`is_super_admin`) — it never appears inside the tenant app.

  The `status` tracks onboarding: `:pending` on creation, moving to `:verified`
  once staff confirm the client's details (or `:rejected`). Verifying stamps
  `verified_at` and relates the acting staff member as `verified_by`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "client_profiles"
    repo Fleetms.Repo

    references do
      reference :organization, on_delete: :delete
      reference :owner, on_delete: :delete
      reference :verified_by, on_delete: :nilify
    end

    # Partial unique indexes (see the identities): one profile per corporate org
    # (owner is nil), and one profile per individual client within the pool.
    identity_wheres_to_sql unique_org_profile: "owner_id IS NULL",
                           unique_owner_profile: "owner_id IS NOT NULL"
  end

  actions do
    defaults [:read]
    default_accept []

    create :create do
      primary? true
      description "Records the KYC details captured when provisioning a client."

      accept [
        :organization_id,
        :owner_id,
        :contact_name,
        :contact_email,
        :contact_phone,
        :address,
        :reg_number,
        :notes
      ]
    end

    update :update do
      primary? true
      description "Edits the KYC details."
      accept [:contact_name, :contact_email, :contact_phone, :address, :reg_number, :notes]
    end

    update :verify do
      description "Marks the client verified and records who confirmed it."
      accept []
      change set_attribute(:status, :verified)
      change set_attribute(:verified_at, &DateTime.utc_now/0)
      change relate_actor(:verified_by)
    end

    update :reject do
      description "Marks the client rejected. Clears any prior verification stamp."
      accept []
      change set_attribute(:status, :rejected)
      change set_attribute(:verified_at, nil)
    end

    read :get_for_organization do
      description "Fetches the profile for a given corporate organization, if any."
      get_by :organization_id
    end

    read :get_for_owner do
      description "Fetches the profile for a given individual client (owner), if any."
      get_by :owner_id
    end

    read :list_individuals do
      description "Every individual client (owner-scoped profiles), newest first."
      filter expr(not is_nil(owner_id))

      prepare build(
                sort: [inserted_at: :desc],
                load: [owner: [:email, profile: [:first_name, :last_name]]]
              )
    end
  end

  policies do
    # Platform staff only — for reading and every write.
    policy always() do
      authorize_if actor_attribute_equals(:is_super_admin, true)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :contact_name, :string, allow_nil?: false, public?: true
    attribute :contact_email, :string, public?: true
    attribute :contact_phone, :string, public?: true
    attribute :address, :string, public?: true

    attribute :reg_number, :string do
      public? true
      description "Business registration / TPIN or an individual's national ID."
    end

    attribute :notes, :string, public?: true

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :verified, :rejected]
      description "Onboarding state: pending review, verified, or rejected."
    end

    attribute :verified_at, :utc_datetime, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, Fleetms.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :owner, Fleetms.Accounts.User do
      attribute_writable? true

      description "The individual client this profile is for (individuals pool); nil for a corporate org, which has one profile for the whole organization."
    end

    belongs_to :verified_by, Fleetms.Accounts.User do
      description "The platform staff member who verified the client."
    end
  end

  identities do
    # A corporate org (owner is nil) has exactly one profile...
    identity :unique_org_profile, [:organization_id] do
      where expr(is_nil(owner_id))
    end

    # ...while each individual client in the shared pool has their own.
    identity :unique_owner_profile, [:organization_id, :owner_id] do
      where expr(not is_nil(owner_id))
    end
  end
end
