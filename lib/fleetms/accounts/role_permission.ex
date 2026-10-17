defmodule Fleetms.Accounts.RolePermission do
  @moduledoc """
  Join resource between tenant-scoped `Role`s and global `Permission`s.

  The `role_id` FK points at the tenant schema's `roles` table; the `permission_id`
  FK is a cross-schema reference to `public.permissions`. AshPostgres infers the
  `public` schema for that FK from the `Permission` resource's `schema "public"`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "role_permissions"
    repo Fleetms.Repo

    references do
      reference :role, on_delete: :delete
      reference :permission, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  actions do
    defaults [:read, :create, :destroy]
  end

  attributes do
    uuid_primary_key :id
    attribute :role_id, :uuid, allow_nil?: false, public?: true
    attribute :permission_id, :uuid, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :role, Fleetms.Accounts.Role,
      source_attribute: :role_id,
      define_attribute?: false

    belongs_to :permission, Fleetms.Accounts.Permission,
      source_attribute: :permission_id,
      define_attribute?: false
  end

  identities do
    identity :unique_role_permission, [:role_id, :permission_id]
  end
end
