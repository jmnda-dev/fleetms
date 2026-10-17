defmodule Fleetms.Accounts.Organization do
  @moduledoc """
  An organization (company/business) signing up to the platform. Each organization
  is a *tenant*: AshPostgres manages a dedicated Postgres schema per organization
  (template `org_<id>`) where its roles and user-role assignments live.

  Users relate to organizations many-to-many through `UserOrganization`. The user
  who creates an organization becomes its owner (a per-org super-admin).
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "organizations"
    repo Fleetms.Repo

    # Create/destroy a dedicated schema per organization and run tenant
    # migrations into it. The tenant string resolves to `org_<id>`.
    manage_tenant do
      template ["org_", :id]
    end
  end

  actions do
    defaults [:read, :destroy]

    read :get_by_id do
      get_by :id
    end

    create :create do
      primary? true
      accept [:name, :account_type]

      argument :owner_user_id, :uuid do
        allow_nil? false
        description "The user who creates the organization becomes its owner."
      end

      change Fleetms.Accounts.Organization.Changes.GeneratePublicId
      change Fleetms.Accounts.Organization.Changes.SetupNewOrganization
    end

    update :update do
      primary? true
      accept [:name]
    end

    # Organization-wide display preferences, edited on the Settings page. Values are
    # stored canonically (metric, UTC) — these only drive how things are shown/entered.
    update :update_settings do
      accept [:account_type, :unit_system, :currency, :timezone, :date_format]
    end

    # --- Platform-admin lifecycle (staff only; enforced by the super-admin bypass) ---

    update :suspend do
      description "Block the org's members from signing in (e.g. non-payment)."
      accept [:suspension_reason]
      change set_attribute(:status, :suspended)
      change set_attribute(:suspended_at, &DateTime.utc_now/0)
    end

    update :reactivate do
      description "Restore a suspended org's access."
      change set_attribute(:status, :active)
      change set_attribute(:suspended_at, nil)
      change set_attribute(:suspension_reason, nil)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # Any authenticated user may create an organization (they become its owner).
    policy action(:create) do
      authorize_if always()
    end

    # Members can read their own organizations.
    policy action_type(:read) do
      authorize_if expr(exists(user_organizations, user_id == ^actor(:id)))
    end

    # Only owners can update/destroy.
    policy action_type([:update, :destroy]) do
      authorize_if expr(exists(user_organizations, user_id == ^actor(:id) and owner? == true))
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true

    # Opaque, immutable URL identifier (see GeneratePublicId). Set once on create
    # via force_change; `writable? false` blocks all changeset writes otherwise.
    attribute :public_id, :string do
      allow_nil? false
      public? true
      writable? false
    end

    attribute :account_type, :atom do
      allow_nil? false
      public? true
      default :business
      constraints one_of: [:individual, :business]

      description "Individual (a personal fleet) or business/corporate. Tailors onboarding and the UI only — the data model is identical."
    end

    # Lifecycle status, managed by platform staff (see the :suspend/:reactivate
    # actions). Suspended orgs block their members at org resolution; staff can
    # still enter. Not user-writable — only the dedicated staff actions change it.
    attribute :status, Fleetms.Accounts.OrganizationStatus do
      allow_nil? false
      public? true
      default :active
      writable? false
      description "Whether the organization's members can access the platform."
    end

    attribute :suspended_at, :utc_datetime do
      public? true
      writable? false
      description "When the organization was suspended (nil while active)."
    end

    attribute :suspension_reason, :string do
      public? true
      constraints max_length: 500
      description "Internal note on why the organization was suspended."
    end

    # The single hidden "individuals pool" org (see Fleetms.Individuals). Not
    # user-writable — set once via Ash.Seed when the pool is provisioned. Every
    # individual client is a member of this org, isolated by `owner_id`.
    attribute :individuals_pool?, :boolean do
      allow_nil? false
      default false
      writable? false
      public? false
      description "Marks the one shared organization that holds all individual clients."
    end

    # --- display settings (see the :update_settings action) ---

    attribute :unit_system, :atom do
      allow_nil? false
      public? true
      default :metric
      constraints one_of: [:metric, :imperial]
      description "Drives how distances/volumes are shown and entered. Data is stored metric."
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
      default "ZMW"
      constraints match: ~r/^[A-Z]{3}$/
      description "Default currency (ISO 4217 code) for new money amounts."
    end

    attribute :timezone, :string do
      allow_nil? false
      public? true
      default "Etc/UTC"
      description "IANA timezone datetimes are shown in. Data is stored in UTC."
    end

    attribute :date_format, :atom do
      allow_nil? false
      public? true
      default :iso
      constraints one_of: [:iso, :us, :eu, :long]
      description "How dates render: iso (2026-08-14), us (08/14/2026), eu (14/08/2026), long."
    end

    timestamps()
  end

  relationships do
    has_many :user_organizations, Fleetms.Accounts.UserOrganization

    # KYC/onboarding details, captured by platform staff. Public-schema, staff-only.
    has_one :client_profile, Fleetms.Accounts.ClientProfile

    many_to_many :users, Fleetms.Accounts.User do
      through Fleetms.Accounts.UserOrganization
      source_attribute_on_join_resource :organization_id
      destination_attribute_on_join_resource :user_id
    end
  end

  aggregates do
    count :member_count, :user_organizations
  end

  identities do
    identity :unique_name, [:name]
    identity :unique_public_id, [:public_id]
  end

  # Allow an `Organization` struct to be passed directly as a `tenant`. Resolves
  # to the schema string `org_<id>`, matching the `manage_tenant` template above.
  defimpl Ash.ToTenant do
    def to_tenant(%{id: id}, _resource), do: "org_#{id}"
  end

  # Render the opaque `public_id` in routes: `~p"/o/#{org}/..."`. The internal
  # UUID stays out of URLs; tenant resolution uses it via Ash.ToTenant above.
  defimpl Phoenix.Param do
    def to_param(%{public_id: public_id}), do: public_id
  end
end
