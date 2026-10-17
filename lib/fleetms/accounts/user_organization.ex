defmodule Fleetms.Accounts.UserOrganization do
  @moduledoc """
  Join resource for the many-to-many relationship between users and organizations.
  Lives in the public schema. The `owner?` flag marks the organization owner — a
  per-org super-admin who bypasses permission checks within that organization.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [Fleetms.Permissions.Dsl]

  postgres do
    table "user_organizations"
    repo Fleetms.Repo

    references do
      reference :user, on_delete: :delete
      reference :organization, on_delete: :delete
    end
  end

  # Declared for the permission catalog / roles UI. Enforcement lives in
  # `Fleetms.Membership` (this resource has no authorizer because the org
  # resolution flow loads memberships before any tenant/permission context
  # exists).
  permissions do
    permission(:view_users,
      action: :read,
      label: "View Users",
      group: "Access Control"
    )

    permission(:manage_users,
      action: [:create, :suspend, :reactivate, :destroy],
      label: "Manage Users",
      group: "Access Control"
    )
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:user_id, :organization_id, :owner?, :status]
      upsert? true
      upsert_identity :unique_user_organization
    end

    update :suspend do
      description "Revoke a member's access to the organization without removing them."
      change set_attribute(:status, :suspended)
    end

    update :reactivate do
      description "Restore a suspended member's access."
      change set_attribute(:status, :active)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :organization_id, :uuid, allow_nil?: false, public?: true
    attribute :owner?, :boolean, default: false, allow_nil?: false, public?: true

    # Whether the member currently has access. Suspended members keep their
    # account and role assignments but cannot act in the organization.
    attribute :status, :atom do
      allow_nil? false
      public? true
      default :active
      constraints one_of: [:active, :suspended]
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Fleetms.Accounts.User,
      source_attribute: :user_id,
      define_attribute?: false

    belongs_to :organization, Fleetms.Accounts.Organization,
      source_attribute: :organization_id,
      define_attribute?: false
  end

  identities do
    identity :unique_user_organization, [:user_id, :organization_id]
  end
end
