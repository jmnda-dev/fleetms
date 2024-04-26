defmodule Fleetms.Accounts.User do
  @moduledoc """
  A User resource
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    domain: Fleetms.Accounts

  alias Fleetms.Accounts.{Organization, Token, UserProfile}

  authentication do
    strategies do
      password :password do
        identity_field :email
      end
    end

    tokens do
      enabled? true
      token_resource Token

      signing_secret fn _, _ ->
        Application.fetch_env(:fleetms, :token_signing_secret)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
      constraints min_length: 3, max_length: 100
    end

    attribute :username, :string do
      allow_nil? true
      public? true
      constraints min_length: 3, max_length: 100
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, Organization do
      allow_nil? false
    end

    has_one :user_profile, UserProfile
  end

  postgres do
    table "users"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    create :register_with_password do
      allow_nil_input [:hashed_password]
      accept [:email]

      argument :password, :string, sensitive?: true
      argument :password_confirmation, :string, sensitive?: true
      argument :user_profile, :map, allow_nil?: false
      argument :organization, :map, allow_nil?: false

      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange

      change manage_relationship(:organization, type: :direct_control)
      change manage_relationship(:user_profile, type: :direct_control)
    end
  end

  identities do
    identity :unique_email, [:email]
    identity :unique_username, [:username]
  end
end
