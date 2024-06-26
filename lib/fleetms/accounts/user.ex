defmodule Fleetms.Accounts.User do
  @moduledoc """
  A User resource
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer],
    domain: Fleetms.Accounts

  require Ash.Query

  alias Fleetms.Accounts.{Organization, Token, UserProfile}
  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager, IsTechnician}

  @password_regex ~r/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$\-_+])[A-Za-z\d!@#$\-_+]+$/
  @invalid_password_msg "Invalid password format. Password should be a combination of lowercase and uppercase letters, numbers, and at least one of these characters: @#$-_+"

  authentication do
    strategies do
      password :password do
        identity_field(:email)
      end
    end

    tokens do
      enabled?(true)
      token_resource(Token)

      signing_secret(fn _, _ ->
        Application.fetch_env(:fleetms, :token_signing_secret)
      end)
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

    attribute :status, :atom do
      allow_nil? false
      default :active
      writable? false
      constraints one_of: Fleetms.Enums.user_statuses()
    end

    attribute :roles, {:array, :atom} do
      allow_nil? false
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

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass IsAdmin do
      authorize_if always()
    end

    policy action(:list) do
      authorize_if IsFleetManager
      authorize_if IsTechnician
    end
  end

  postgres do
    table "users"
    repo Fleetms.Repo
  end

  actions do
    defaults [:destroy]

    create :register_with_password do
      allow_nil_input [:hashed_password]
      accept [:email]

      argument :password, :string do
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      argument :password_confirmation, :string do
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      argument :user_profile, :map, allow_nil?: false
      argument :organization, :map, allow_nil?: false

      validate match(:email, ~r/^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$/) do
        message "Invalid email format"
      end

      validate match(:password, @password_regex) do
        message @invalid_password_msg
      end

      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation
      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange

      change manage_relationship(:organization, type: :direct_control)
      change manage_relationship(:user_profile, type: :direct_control)
      change set_attribute(:roles, [:admin])
    end

    create :create_organization_user do
      allow_nil_input [:hashed_password]
      accept [:email, :roles]

      argument :password, :string do
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      argument :password_confirmation, :string do
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      argument :user_profile, :map, allow_nil?: false
      argument :organization_id, :uuid, allow_nil?: false

      validate match(:email, ~r/^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$/) do
        message "Invalid email format"
      end

      validate match(:password, @password_regex) do
        message @invalid_password_msg
      end

      change set_context(%{strategy_name: :password})
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation
      change AshAuthentication.Strategy.Password.HashPasswordChange

      change manage_relationship(:organization_id, :organization, type: :append_and_remove)
      change manage_relationship(:user_profile, type: :direct_control)

      change after_action(fn _changeset, created_user, _context ->
               {:ok, Ash.load!(created_user, :full_name)}
             end)
    end

    read :list do
      primary? true

      prepare build(load: [:full_name])
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      get? true
      filter expr(id == ^arg(:id))
    end

    update :update do
      primary? true
      require_atomic? false
      allow_nil_input [:hashed_password]
      accept [:email, :roles]

      argument :user_status, :atom do
        constraints one_of: Fleetms.Enums.user_statuses()
      end

      argument :password, :string do
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      argument :password_confirmation, :string do
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      validate match(:email, ~r/^[\w\-\.]+@([\w-]+\.)+[\w-]{2,}$/) do
        message "Invalid email format"
      end

      validate match(:password, @password_regex) do
        message @invalid_password_msg
      end

      change set_context(%{strategy_name: :password})
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation
      change AshAuthentication.Strategy.Password.HashPasswordChange
      change set_attribute(:status, arg(:user_status))
    end
  end

  identities do
    identity :unique_email, [:email] do
      eager_check? true
    end

    identity :unique_username, [:username] do
      eager_check? true
    end
  end

  preparations do
    prepare fn query, %{actor: actor} = _context ->
      if is_nil(actor) do
        query
      else
        Ash.Query.filter(query, organization_id == ^actor.organization_id)
      end
    end

    prepare build(load: [:full_name, :user_profile])
  end

  calculations do
    calculate :full_name, :string, expr(user_profile.full_name)
  end
end
