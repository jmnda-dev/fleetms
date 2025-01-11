defmodule Fleetms.Accounts.User do
  @moduledoc """
  A User resource
  """

  defimpl FunWithFlags.Actor, for: __MODULE__ do
    def id(%{id: id}), do: "user:#{id}"
  end

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer],
    domain: Fleetms.Accounts

  require Ash.Query

  alias Ash.Error.Framework.AssumptionFailed
  alias Fleetms.Accounts.{Organization, Token, UserProfile}
  alias __MODULE__.Policies.{IsAdmin, IsFleetManager, IsTechnician}
  alias __MODULE__.Validations.ValidateCurrentPassword

  @default_sorting_params %{sort_by: :updated_at, sort_order: :desc}
  @password_regex ~r/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$\-_+])[A-Za-z\d!@#$\-_+]+$/
  @invalid_password_msg "Invalid password format. Password should be a combination of lowercase and uppercase letters, numbers, and at least one of these characters: @#$-_+"

  authentication do
    strategies do
      password :password do
        identity_field :email

        resettable do
          sender Fleetms.Accounts.User.Senders.SendPasswordResetEmail
        end
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

    attribute :roles, {:array, :atom} do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :Active
      writable? false
      constraints one_of: Fleetms.Enums.user_statuses()
    end

    attribute :is_service_provider, :boolean do
      allow_nil? false
      default false
      writable? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :organization, Organization do
      allow_nil? false
    end
    # has_many :assigned_work_orders, Fleetms.VehicleMaintenance.Or

    has_one :user_profile, UserProfile
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass IsAdmin do
      authorize_if always()
    end

    # TODO: Temporary fix for load relationships to work when actor is not admin
    policy action(:read) do
      authorize_if always()
    end

    policy action_type(:action) do
      authorize_if always()
    end

    policy action(:request_password_reset_with_password) do
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

      change after_action(fn changeset, created_user, _context ->
               {:ok, Ash.load!(created_user, :full_name)}
             end)
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      get? true
      filter expr(id == ^arg(:id))
    end

    update :update do
      primary? true
      require_atomic? false
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

    update :change_password do
      require_atomic? false

      argument :current_password, :string do
        allow_nil? false
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      argument :new_password, :string do
        allow_nil? false
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      argument :new_password_confirmation, :string do
        allow_nil? false
        sensitive? true
        constraints min_length: 8, max_length: 32
      end

      validate confirm(:new_password, :new_password_confirmation)

      validate match(:password, @password_regex) do
        message @invalid_password_msg
      end

      validate ValidateCurrentPassword do
        only_when_valid? true
      end

      change set_context(%{private: %{ash_authentication?: true}})

      change fn changeset, _context ->
        with {:ok, strategy} <- AshAuthentication.Info.strategy(__MODULE__, :password),
             value when is_binary(value) <- Ash.Changeset.get_argument(changeset, :new_password),
             {:ok, hash} <- strategy.hash_provider.hash(value) do
          Ash.Changeset.change_attribute(changeset, strategy.hashed_password_field, hash)
        else
          :error ->
            raise AssumptionFailed, message: "Something went wrong while updating password"

          _ ->
            changeset
        end
      end
    end

    read :read, primary?: true

    read :get_all do
      prepare build(load: [:organization, user_profile: [:full_name]])
    end

    read :list do
      pagination offset?: true, countable: true

      argument :paginate_sort_opts, :map, default: @default_sorting_params
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}
      # TODO: This is a temporay fix, to filter users by a tenant
      argument :current_organization_id, :uuid, allow_nil?: false

      prepare build(load: [:full_name])

      prepare fn query, context ->
        %{sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        advanced_filter_params = Ash.Query.get_argument(query, :advanced_filter_params)

        query =
          Enum.reduce(advanced_filter_params, query, fn
            {_, nil}, accumulated_query ->
              accumulated_query

            {_, []}, accumulated_query ->
              accumulated_query

            {_, "All"}, accumulated_query ->
              accumulated_query

            {_, :All}, accumulated_query ->
              accumulated_query

            {:roles, roles}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(role in ^roles)
              )

            {:status, statuses}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(status in ^statuses)
              )
          end)
          |> Ash.Query.load([
            :user_profile
          ])
          |> Ash.Query.sort([{sort_by, sort_order}])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(first_name, ^search_query) > 0.1 or
                trigram_similarity(last_name, ^search_query) > 0.1 or
                trigram_similarity(user_profile.middle_name, ^search_query) > 0.3 or
                trigram_similarity(email, ^search_query) > 0.3 or
                trigram_similarity(role, ^search_query) > 0.3 or
                trigram_similarity(user_profile.mobile, ^search_query) > 0.3
            )
          )
        end
      end

      filter expr(organization_id == ^arg(:current_organization_id))
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
