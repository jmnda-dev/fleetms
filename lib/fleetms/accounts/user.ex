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

  @default_listing_limit 20
  @default_sorting_params %{sort_by: :created_at, sort_order: :desc}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}
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

    policy action_type(:action) do
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

    action :validate_sorting_params, :map do
      description "Validates the Sorting params from the URL e.g /?sort_by=name&sort_order=desc"
      argument :url_params, :map, allow_nil?: false

      run fn input, _context ->
        params =
          %{
            sort_order: Map.get(input.arguments.url_params, "sort_order", "desc"),
            sort_by: Map.get(input.arguments.url_params, "sort_by", "updated_at")
          }

        types = %{
          sort_order:
            Ecto.ParameterizedType.init(Ecto.Enum, values: [asc: "Ascending", desc: "Descending"]),
          sort_by:
            Ecto.ParameterizedType.init(Ecto.Enum,
              values: [
                created_at: "Date Created",
                updated_at: "Date Updated",
                first_name: "First Name",
                last_name: "Last Name",
                role: "Role",
                status: "Status"
              ]
            )
        }

        data = %{}

        {data, types}
        |> Ecto.Changeset.cast(params, Map.keys(types))
        |> Ecto.Changeset.apply_action(:create)
        |> case do
          {:ok, sort_params} ->
            {:ok, sort_params}

          {:error, changeset} ->
            {:ok, @default_sorting_params}
        end
      end
    end

    action :validate_pagination_params, :map do
      description "Validates the Pagination params from the URL e.g /?page=1&per_page=10"
      argument :url_params, :map, allow_nil?: false

      run fn input, _context ->
        params =
          %{
            page: Map.get(input.arguments.url_params, "page", 1),
            per_page: Map.get(input.arguments.url_params, "per_page", @default_listing_limit)
          }

        types = %{
          page: :integer,
          per_page: :integer
        }

        data = %{}

        {data, types}
        |> Ecto.Changeset.cast(params, Map.keys(types))
        |> Ecto.Changeset.apply_action(:create)
        |> case do
          {:ok, paginate_params} ->
            {:ok, paginate_params}

          {:error, _changeset} ->
            {:ok, @default_paginate_params}
        end
      end
    end

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

    read :read, primary?: true

    read :get_all do
      prepare build(load: [:organization, user_profile: [:full_name]])
    end

    read :list do
      pagination offset?: true, default_limit: 50, countable: true

      argument :paginate_sort_opts, :map, default: @default_sorting_params
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}
      argument :current_organization_id, :uuid, allow_nil?: false # TODO: This is a temporay fix, to filter users by a tenant

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

  code_interface do
    define :validate_sorting_params, action: :validate_sorting_params, args: [:url_params]
    define :validate_pagination_params, action: :validate_pagination_params, args: [:url_params]
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
