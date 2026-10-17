defmodule Fleetms.Accounts.PlatformAccessLog do
  @moduledoc """
  An audit record of platform staff (a super-admin) entering an organization they
  are not a member of, to act on the client's behalf.

  Public-schema (non-tenant): it spans organizations. Written when staff enter an
  org from the admin console, and only ever readable/writable by platform staff.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "platform_access_logs"
    repo Fleetms.Repo

    references do
      reference :admin_user, on_delete: :delete
      reference :organization, on_delete: :delete
    end
  end

  actions do
    defaults [:read]
    default_accept []

    create :record do
      description "Records that the acting staff member entered an organization."
      accept [:organization_id]
      change relate_actor(:admin_user)
    end

    read :list do
      argument :organization_id, :uuid, allow_nil?: true

      prepare build(
                sort: [inserted_at: :desc],
                load: [admin_user: [:email], organization: [:name]]
              )

      filter expr(is_nil(^arg(:organization_id)) or organization_id == ^arg(:organization_id))

      pagination offset?: true, countable: true, default_limit: 50, max_page_size: 200
    end
  end

  policies do
    # Platform staff only — for both recording and reading access logs.
    policy always() do
      authorize_if actor_attribute_equals(:is_super_admin, true)
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :admin_user, Fleetms.Accounts.User do
      allow_nil? false
    end

    belongs_to :organization, Fleetms.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
    end
  end
end
