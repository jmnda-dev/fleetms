defmodule Fleetms.Accounts.UserRole do
  @moduledoc """
  Assigns a tenant `Role` to a `User` within an organization. The `role_id` FK is
  same-schema (tenant); the `user_id` FK is a cross-schema reference to
  `public.users`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshJsonApi.Resource]

  postgres do
    table "user_roles"
    repo Fleetms.Repo

    references do
      reference :role, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  permissions do
    permission :view_user_roles,
      action: :read,
      label: "View User Role Assignments",
      group: "Access Control"

    permission :assign_user_roles,
      action: [:assign, :revoke],
      label: "Assign / Revoke User Roles",
      group: "Access Control"
  end

  json_api do
    type "user-role"
  end

  actions do
    defaults [:read]

    create :assign do
      accept [:user_id, :role_id]
      upsert? true
      upsert_identity :unique_user_role
    end

    destroy :revoke do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if {Fleetms.Permissions.Check, permission: :view_user_roles}
    end

    policy action(:assign) do
      authorize_if {Fleetms.Permissions.Check, permission: :assign_user_roles}
    end

    policy action(:revoke) do
      authorize_if {Fleetms.Permissions.Check, permission: :assign_user_roles}
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id
    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :role_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :user, Fleetms.Accounts.User,
      source_attribute: :user_id,
      define_attribute?: false

    belongs_to :role, Fleetms.Accounts.Role,
      source_attribute: :role_id,
      define_attribute?: false
  end

  identities do
    identity :unique_user_role, [:user_id, :role_id]
  end
end
