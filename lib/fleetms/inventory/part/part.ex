defmodule Fleetms.Inventory.Part do
  use Ash.Resource,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  require Ash.Query
  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}

  @default_listing_limit 20
  @default_sorting_params %{sort_by: :created_at, sort_order: :desc}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
    end

    attribute :part_number, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :oem_part_number, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :unit_cost, AshMoney.Types.Money do
      allow_nil? true
      public? true
    end

    attribute :unit_measurement, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :quantity_threshold, :decimal do
      allow_nil? true
      public? true
      constraints min: 0, max: 9_999_999_999
      default 0
    end

    attribute :track_inventory, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :stock_quantity, :decimal do
      allow_nil? true
      public? true
      default 0
      writable? false
    end

    attribute :stock_quantity_status, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.stock_quantity_statuses()
      default :"Not tracked"
      writable? false
    end

    attribute :documents, {:array, Fleetms.Inventory.PartDocument} do
      allow_nil? true
    end

    attribute :photo, :string

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :part_manufacturer, Fleetms.Inventory.PartManufacturer

    many_to_many :vendors, Fleetms.Common.Vendor do
      domain Fleetms.Common
      through Fleetms.Common.VendorPart
      source_attribute_on_join_resource :part_id
      destination_attribute_on_join_resource :vendor_id
    end

    many_to_many :inventory_locations, Fleetms.Inventory.InventoryLocation do
      through Fleetms.Inventory.PartInventoryLocation
      source_attribute_on_join_resource :part_id
      destination_attribute_on_join_resource :inventory_location_id
      join_relationship :part_inventory_locations
    end

    belongs_to :part_category, Fleetms.Inventory.PartCategory
    has_many :part_photos, Fleetms.Inventory.PartPhoto
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
    end

    policy action([
             :save_part_photos,
             :maybe_delete_existing_photos,
             :update_from_part_inventory_location
           ]) do
      authorize_if always()
    end
  end

  postgres do
    table "parts"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read]

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

    action :get_dashboard_stats, :map do
      import Ecto.Query

      argument :tenant, :string, allow_nil?: false

      run fn input, _context ->
        tenant = input.arguments.tenant

        {:ok, parts_ecto_query} =
          Fleetms.Inventory.Part
          |> Ash.Query.set_tenant(tenant)
          |> Ash.Query.data_layer_query()

        {:ok, inventory_locations_ecto_query} =
          Fleetms.Inventory.InventoryLocation
          |> Ash.Query.set_tenant(tenant)
          |> Ash.Query.data_layer_query()

        new_query =
          from p in parts_ecto_query,
            join: il in ^inventory_locations_ecto_query,
            on: true,
            select: %{
              total_parts: count(p.id, :distinct),
              total_inventory_locations: count(il.id, :distinct)
            }

        {:ok, Fleetms.Repo.one!(new_query)}
      end
    end

    create :create do
      accept :*

      argument :part_manufacturer_id, :uuid do
        allow_nil? true
      end

      argument :part_category_id, :uuid do
        allow_nil? true
      end

      argument :part_inventory_locations, {:array, :map} do
        allow_nil? true
      end

      argument :vendors, {:array, :uuid} do
        allow_nil? true
        default []
      end

      change manage_relationship(:part_manufacturer_id, :part_manufacturer,
               type: :append_and_remove
             )

      change manage_relationship(:part_category_id, :part_category, type: :append_and_remove)
      change manage_relationship(:part_inventory_locations, type: :direct_control)
      change manage_relationship(:vendors, type: :append_and_remove)
      change Fleetms.Inventory.Part.Changes.SetStock
    end

    update :update do
      require_atomic? false
      accept :*

      argument :part_manufacturer_id, :uuid do
        allow_nil? true
      end

      argument :part_category_id, :uuid do
        allow_nil? true
      end

      argument :part_inventory_locations, {:array, :map} do
        allow_nil? true
      end

      argument :vendors, {:array, :uuid} do
        allow_nil? true
        default []
      end

      validate Fleetms.Inventory.Resources.Part.Validations.ValidateInventoryTracking do
        only_when_valid? true
      end

      change manage_relationship(:part_manufacturer_id, :part_manufacturer,
               type: :append_and_remove
             )

      change manage_relationship(:part_category_id, :part_category, type: :append_and_remove)
      change manage_relationship(:part_inventory_locations, type: :direct_control)
      change manage_relationship(:vendors, type: :append_and_remove)
      change Fleetms.Inventory.Part.Changes.SetStock
    end

    update :update_from_part_inventory_location do
      require_atomic? false
      change Fleetms.Inventory.Part.Changes.SetStock
    end

    update :save_part_photos do
      accept [:photo]
      require_atomic? false
      argument :part_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:part_photos, type: :direct_control)
    end

    update :maybe_delete_existing_photos do
      accept [:photo]
      require_atomic? false

      argument :current_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:current_photos, :part_photos, type: :direct_control)
    end

    read :list do
      pagination offset?: true, default_limit: 50, countable: true

      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      prepare fn query, _context ->
        %{page: page, per_page: per_page, sort_order: sort_order, sort_by: sort_by} =
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

            {:part_manufacturers, part_manufacturer_ids}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(part_manufacturer_id in ^part_manufacturer_ids)
              )

            {:part_categories, part_category_ids}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(part_category_id in ^part_category_ids)
              )

            {:unit_cost_min, unit_cost_min}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(unit_cost >= ^unit_cost_min)
              )

            {:unit_cost_max, unit_cost_max}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(unit_cost <= ^unit_cost_max)
              )
          end)
          |> Ash.Query.load([
            :manufacturer_name,
            :category_name
          ])
          |> Ash.Query.sort([{sort_by, sort_order}])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(name, ^search_query) > 0.1 or
                trigram_similarity(part_number, ^search_query) > 0.1 or
                trigram_similarity(oem_part_number, ^search_query) > 0.1 or
                trigram_similarity(part_manufacturer.name, ^search_query) > 0.1 or
                trigram_similarity(part_category.name, ^search_query) > 0.1 or
                trigram_similarity(unit_measurement, ^search_query) > 0.1 or
                trigram_similarity(description, ^search_query) > 0.1
            )
          )
        end
      end
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :part_photos,
                  :vendors,
                  part_inventory_locations: [inventory_location: [:count_of_parts]]
                ]
              )
    end

    read :get_all do
      prepare build(load: [:part_manufacturer])
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_record ->
          Enum.map(deleted_record.part_photos, fn
            %{filename: filename, part_id: part_id} = _part_photo ->
              scope = %{id: part_id}
              Fleetms.PartPhoto.delete({filename, scope})
          end)

          {:ok, deleted_record}
        end)
      end
    end
  end

  code_interface do
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :get_all, action: :get_all
    define :validate_sorting_params, action: :validate_sorting_params, args: [:url_params]
    define :validate_pagination_params, action: :validate_pagination_params, args: [:url_params]
    define :get_dashboard_stats, action: :get_dashboard_stats, args: [:tenant]
  end

  identities do
    identity :unique_name_and_part_number, [:name, :part_number]
  end

  aggregates do
    first :manufacturer_name, :part_manufacturer, :name
    first :category_name, :part_category, :name
    # sum :stock_quantity, :part_inventory_locations, :quantity do
    #   filterable? true
    # end
  end

  # calculations do
  #   calculate :stock_quantity_status, :atom, expr(
  #       cond do
  #         track_inventory == true and stock_quantity == 0 ->
  #           :"Out of Stock"
  #         track_inventory == true and stock_quantity > quantity_threshold ->
  #           :"In Stock"
  #
  #         track_inventory == true and stock_quantity <= quantity_threshold ->
  #           :"Stock Low"
  #         true ->
  #           :"Not tracked"
  #       end
  #     )
  # end

  multitenancy do
    strategy :context
  end
end
