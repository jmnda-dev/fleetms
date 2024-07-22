defmodule Fleetms.Inventory.PartInventoryLocation do
  use Ash.Resource,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  require Ash.Query

  @default_listing_limit 20
  @default_sorting_params %{sort_by: :desc, sort_order: :created_at}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}

  attributes do
    uuid_primary_key :id

    attribute :quantity, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
      default 0
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :part, Fleetms.Inventory.Part do
      allow_nil? false
      destination_attribute :id
      primary_key? true
    end

    belongs_to :inventory_location, Fleetms.Inventory.InventoryLocation do
      allow_nil? false
      destination_attribute :id
      primary_key? true
    end
  end

  policies do
    policy action_type(:action) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action([:create, :update, :destroy, :update_stock_quantity]) do
      authorize_if always()
    end
  end

  postgres do
    table "part_inventory_location"
    repo Fleetms.Repo

    references do
      reference :part, on_delete: :delete
      reference :inventory_location, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

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
                name: "Part Name",
                part_number: "Part Number",
                oem_part_number: "OEM Part Number",
                unit_cost: "Unit Cost",
                category_name: "Category Name",
                manufacturer_name: "Manufacturer Name"
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

    create :create do
      primary? true
      accept :*
      argument :part_id, :uuid
      argument :inventory_location_id, :uuid, allow_nil?: false

      change manage_relationship(:part_id, :part, type: :append_and_remove)

      change manage_relationship(:inventory_location_id, :inventory_location,
               type: :append_and_remove
             )
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :part_id, :uuid
      argument :inventory_location_id, :uuid, allow_nil?: false

      change manage_relationship(:part_id, :part, type: :append_and_remove)

      change manage_relationship(:inventory_location_id, :inventory_location,
               type: :append_and_remove
             )
    end

    update :update_stock_quantity do
      require_atomic? false
      accept :*
      argument :quantity, :decimal, allow_nil?: false
      argument :part_id, :uuid

      change fn changeset, _context ->
        current_stock_quantity = Ash.Changeset.get_attribute(changeset, :quantity)
        deducting_quantity = Ash.Changeset.get_argument(changeset, :quantity)

        Ash.Changeset.change_attribute(
          changeset,
          :quantity,
          Decimal.sub(current_stock_quantity, deducting_quantity)
        )
      end

      change manage_relationship(:part_id, :part, on_lookup: :relate, on_match: {:update, :update_from_part_inventory_location})
    end

    read :list do
      pagination offset?: true, default_limit: 50, countable: true

      argument :inventory_location_id, :uuid, allow_nil?: false
      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""

      filter expr(inventory_location_id == ^arg(:inventory_location_id))

      prepare fn query, _context ->
        %{page: page, per_page: per_page, sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)

        query =
          Ash.Query.load(query,
            part: [
              :manufacturer_name,
              :category_name
            ]
          )
          |> Ash.Query.offset((page - 1) * per_page)
          |> Ash.Query.limit(per_page)

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(part.name, ^search_query) > 0.1 or
                trigram_similarity(part.part_number, ^search_query) > 0.1 or
                trigram_similarity(part.oem_part_number, ^search_query) > 0.1 or
                trigram_similarity(part.part_manufacturer.name, ^search_query) > 0.1 or
                trigram_similarity(part.part_category.name, ^search_query) > 0.1 or
                trigram_similarity(part.unit_measurement, ^search_query) > 0.1 or
                trigram_similarity(part.description, ^search_query) > 0.1
            )
          )
        end
      end
    end

    read :get_by_part_and_location do
      argument :part_id, :uuid
      argument :inventory_location_id, :uuid

      filter expr(
               part_id == ^arg(:part_id) and inventory_location_id == ^arg(:inventory_location_id)
             )
    end
  end

  identities do
    identity :unique_part_inventory_location, [:inventory_location_id, :part_id]
  end

  code_interface do


    define :get_by_part_and_location,
      action: :get_by_part_and_location,
      args: [:part_id, :inventory_location_id],
      get?: true
  end

  multitenancy do
    strategy :context
  end
end
