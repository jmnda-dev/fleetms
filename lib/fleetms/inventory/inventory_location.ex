defmodule Fleetms.Inventory.InventoryLocation do
  use Ash.Resource,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]
  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}
  require Ash.Query

  @default_listing_limit 20
  @default_sorting_params %{sort_by: :desc, sort_order: :created_at}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 500
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :inventory_location_parts, Fleetms.Inventory.PartInventoryLocation
  end

  postgres do
    table "inventory_locations"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

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
                name: "Part Name"
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

    read :list do
      pagination offset?: true, default_limit: 50, countable: true

      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""

      prepare fn query, _context ->
        %{page: page, per_page: per_page, sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)

        query =
          query
          |> Ash.Query.load([
            :count_of_parts
          ])
          |> Ash.Query.sort([{sort_by, sort_order}])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(name, ^search_query) > 0.1 or
                trigram_similarity(description, ^search_query) > 0.1
            )
          )
        end
      end
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))
      prepare build(load: [:count_of_parts])
    end

    read :get_all
  end

  policies do
    policy action_type(:action) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action([:create, :update, :destroy]) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if accessing_from(Fleetms.Inventory.Part, :inventory_locations)
    end
  end

  aggregates do
    count :count_of_parts, :inventory_location_parts
  end

  code_interface do

    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :get_all, action: :get_all
    define :validate_sorting_params, action: :validate_sorting_params, args: [:url_params]
    define :validate_pagination_params, action: :validate_pagination_params, args: [:url_params]
  end

  identities do
    identity :unique_name, [:name]
  end

  multitenancy do
    strategy :context
  end
end
