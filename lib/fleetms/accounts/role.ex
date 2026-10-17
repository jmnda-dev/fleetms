defmodule Fleetms.Accounts.Role do
  @moduledoc """
  A named bundle of permissions, scoped to a single organization (tenant schema).
  System roles (`is_system: true`) are auto-seeded on organization creation and
  cannot be renamed or deleted by org users.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshJsonApi.Resource]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "roles"
    repo Fleetms.Repo
  end

  permissions do
    permission :view_roles,
      action: :read,
      label: "View Roles",
      group: "Access Control"

    permission :create_role,
      action: :create,
      label: "Create Role",
      group: "Access Control"

    permission :update_role,
      action: [:update, :set_permissions],
      label: "Update Role",
      group: "Access Control"

    permission :delete_role,
      action: :destroy,
      label: "Delete Role",
      group: "Access Control"
  end

  json_api do
    type "role"
  end

  actions do
    defaults [:read]

    read :get_by_id do
      get_by :id
    end

    create :create do
      primary? true
      accept [:name, :description, :organization_id]
      change set_attribute(:is_system, false)
    end

    # Internal-only action used by the seeder.
    create :seed_system_role do
      accept [:name, :description, :organization_id]
      change set_attribute(:is_system, true)
    end

    update :update do
      primary? true
      accept [:name, :description]

      validate attribute_does_not_equal(:is_system, true) do
        message "System roles cannot be modified."
      end
    end

    destroy :destroy do
      primary? true

      validate attribute_does_not_equal(:is_system, true) do
        message "System roles cannot be deleted."
      end
    end

    # Assign permissions to a role (replaces all).
    update :set_permissions do
      require_atomic? false
      argument :permission_ids, {:array, :uuid}, allow_nil?: false

      change manage_relationship(:permission_ids, :permissions,
               type: :direct_control,
               on_lookup: :relate,
               on_missing: :unrelate,
               on_no_match: :error,
               on_match: :ignore
             )
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_roles)
    end

    policy action(:create) do
      authorize_if has_permission(:create_role)
    end

    policy action([:update, :set_permissions]) do
      authorize_if has_permission(:update_role)
    end

    policy action(:destroy) do
      authorize_if has_permission(:delete_role)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :is_system, :boolean, default: false, allow_nil?: false, public?: true
    attribute :organization_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :organization, Fleetms.Accounts.Organization,
      source_attribute: :organization_id,
      define_attribute?: false,
      attribute_writable?: true

    has_many :role_permissions, Fleetms.Accounts.RolePermission

    many_to_many :permissions, Fleetms.Accounts.Permission do
      through Fleetms.Accounts.RolePermission
      source_attribute_on_join_resource :role_id
      destination_attribute_on_join_resource :permission_id
    end

    has_many :user_roles, Fleetms.Accounts.UserRole

    many_to_many :users, Fleetms.Accounts.User do
      through Fleetms.Accounts.UserRole
      source_attribute_on_join_resource :role_id
      destination_attribute_on_join_resource :user_id
    end
  end

  identities do
    identity :unique_name_per_org, [:name]
  end
end
