defmodule Fleetms.Accounts.ApiKey do
  @moduledoc """
  A long-lived API key that authenticates a user for server-to-server access to
  the JSON:API. Keys are stored only as a SHA-256 hash; the plaintext is shown
  once, at creation, and never again.

  A key authenticates the *user* — the organization (tenant) is still chosen per
  request via the `x-organization` header, so a key inherits exactly the user's
  memberships and permissions.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo Fleetms.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    read :list_for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [inserted_at: :desc])
    end

    create :create do
      primary? true
      accept [:user_id, :expires_at]

      # Puts the generated plaintext key into the record metadata (shown once).
      metadata :plaintext_api_key, :string, allow_nil?: false

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey,
              prefix: :fleetms, hash: :api_key_hash}
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # A user manages only their own keys.
    policy action_type([:read, :create, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :user, Fleetms.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :valid, :boolean, expr(expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
