defmodule Fleetms.Accounts.Invitation do
  @moduledoc """
  A pending invitation for someone to join an organization by email. Lives in the
  public schema (an invitee may not have an account yet, so it can't be tenant
  data). Only the SHA-256 hash of the single-use token is stored; the plain token
  is emailed and never persisted.

  Membership is created when the invitation is accepted — see `Fleetms.Membership`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  alias Fleetms.Accounts.Invitation.Changes.GenerateToken

  postgres do
    table "invitations"
    repo Fleetms.Repo

    references do
      reference :organization, on_delete: :delete
      reference :invited_by, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    read :get_by_token do
      description "Look up a pending, unexpired invitation by its plain token."
      argument :token, :string, allow_nil?: false
      get? true

      prepare fn query, _context ->
        hashed = GenerateToken.hash(Ash.Query.get_argument(query, :token))

        Ash.Query.filter(
          query,
          hashed_token == ^hashed and status == :pending and expires_at > now()
        )
      end
    end

    create :invite do
      description "Create an invitation and email the link to the invitee."
      accept [:email, :organization_id, :role_id, :invited_by_id]

      argument :organization_name, :string, allow_nil?: false

      change set_attribute(:status, :pending)
      change Fleetms.Accounts.Invitation.Changes.Invite
    end

    update :accept do
      description "Mark the invitation accepted (membership creation is orchestrated)."
      change set_attribute(:status, :accepted)
    end

    update :revoke do
      change set_attribute(:status, :revoked)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # Management is enforced in `Fleetms.Membership` (which checks `manage_users`);
    # token-based reads/accepts run with `authorize?: false` because the invitee
    # has no actor yet.
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :organization_id, :uuid, allow_nil?: false, public?: true

    # The tenant role to assign on acceptance (a Role id from the org's schema).
    attribute :role_id, :uuid, public?: true
    attribute :invited_by_id, :uuid, public?: true

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :accepted, :revoked]
    end

    attribute :hashed_token, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec, allow_nil?: false

    timestamps()
  end

  relationships do
    belongs_to :organization, Fleetms.Accounts.Organization do
      source_attribute :organization_id
      define_attribute? false
    end

    belongs_to :invited_by, Fleetms.Accounts.User do
      source_attribute :invited_by_id
      define_attribute? false
    end
  end

  identities do
    identity :unique_hashed_token, [:hashed_token]
  end
end
