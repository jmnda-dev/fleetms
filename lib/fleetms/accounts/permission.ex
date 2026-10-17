defmodule Fleetms.Accounts.Permission do
  @moduledoc """
  A globally-declared permission. Permissions are owned by code (declared via the
  `Fleetms.Permissions.Dsl` extension) and synced into the `public.permissions`
  table on boot. They are never tenant-scoped.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "permissions"
    # ALWAYS public — not tenant-scoped. Cross-schema FKs from tenant
    # `role_permissions` rows point here.
    schema "public"
    repo Fleetms.Repo
  end

  json_api do
    type "permission"
  end

  actions do
    defaults [:read, :destroy]

    # Used by the boot-time sync process.
    create :upsert do
      accept [:name, :label, :description, :group, :resource_module, :action_name, :active]
      upsert? true
      upsert_identity :unique_name

      upsert_fields [
        :label,
        :description,
        :group,
        :resource_module,
        :action_name,
        :active,
        :updated_at
      ]
    end

    update :deactivate do
      accept []
      change set_attribute(:active, false)
    end

    update :reactivate do
      accept []
      change set_attribute(:active, true)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :label, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :group, :string, public?: true
    attribute :resource_module, :string, allow_nil?: false, public?: true
    attribute :action_name, :string, allow_nil?: false, public?: true
    attribute :active, :boolean, default: true, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    has_many :role_permissions, Fleetms.Accounts.RolePermission
  end

  identities do
    identity :unique_name, [:name]
  end
end
