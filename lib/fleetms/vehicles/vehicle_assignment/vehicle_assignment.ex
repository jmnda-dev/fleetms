defmodule Fleetms.Vehicles.VehicleAssignment do
  @moduledoc """
  Defines the vehicle assignment resource.
  """

  use Ash.Resource,
    domain: Fleetms.Vehicles,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  @default_listing_limit 20
  @default_sorting_params %{sort_by: :desc, sort_order: :created_at}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}

  attributes do
    uuid_primary_key :id

    attribute :start_datetime, :utc_datetime do
      allow_nil? false
      public? true
      description "The date and time the vehicle was assigned."
    end

    attribute :end_datetime, :utc_datetime do
      allow_nil? true
      public? true
      description "The date and time the vehicle was unassigned."
    end

    attribute :start_mileage, :decimal do
      allow_nil? true
      public? true
      description "The mileage of the vehicle when it was assigned."
    end

    attribute :end_mileage, :decimal do
      allow_nil? true
      public? true
      description "The mileage of the vehicle when it was unassigned."
    end

    attribute :comments, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 500
      description "Comments about the vehicle assignment."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.Vehicles.Vehicle do
      allow_nil? false
      description "The vehicle that was assigned."
    end

    belongs_to :assignee, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? false
      description "The user/driver that was assigned to the vehicle."
      source_attribute :assignee_id
      destination_attribute :id
    end
  end

  postgres do
    table "vehicle_assignments"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :assignee_id, :uuid, allow_nil?: false

      validate Fleetms.Vehicles.VehicleAssignment.Validations.ValidateStartAndEndDatetime do
        only_when_valid? true
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:assignee_id, :assignee, type: :append_and_remove)
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :assignee_id, :uuid, allow_nil?: false

      validate Fleetms.Vehicles.VehicleAssignment.Validations.ValidateStartAndEndDatetime do
        only_when_valid? true
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:assignee_id, :assignee, type: :append_and_remove)
    end

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
                start_datetime: "Start Datetime",
                end_datetime: "End Datetime",
                start_mileage: "Start Mileage",
                end_mileage: "End Mileage",
                created_at: "Date Created",
                updated_at: "Date Updated",
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

    read :list do
      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      pagination offset?: true, default_limit: @default_listing_limit, countable: true

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

            {:statuses, statuses}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(status in ^statuses))

            {:start_mileage_min, mileage_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(start_mileage >= ^mileage_min))

            {:start_mileage_max, mileage_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(start_mileage <= ^mileage_max))

            {:end_mileage_min, mileage_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(end_mileage >= ^mileage_min))

            {:end_mileage_max, mileage_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(end_mileage <= ^mileage_max))

            {:start_date_min, start_date_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(start_datetime >= ^start_date_min))

            {:start_date_max, start_date_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(start_datetime <= ^start_date_max))

            {:end_date_min, end_date_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(end_datetime >= ^end_date_min))

            {:end_date_max, end_date_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(end_datetime <= ^end_date_max))

            {:vehicles, vehicle_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_id in ^vehicle_ids))

            {:assignees, assignee_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(assignee_id in ^assignee_ids))

            _, accumulated_query ->
              accumulated_query
          end)
          |> Ash.Query.offset((page - 1) * per_page)
          |> Ash.Query.limit(per_page)
          |> Ash.Query.sort([{sort_by, sort_order}])
          |> Ash.Query.load(
            assignee: [:user_profile],
            vehicle: [:full_name]
          )

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(vehicle.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.vehicle_make.name, ^search_query) > 0.1 or
                trigram_similarity(assignee.user_profile.first_name, ^search_query) > 0.1 or
                trigram_similarity(assignee.user_profile.middle_name, ^search_query) > 0.1 or
                trigram_similarity(assignee.user_profile.last_name, ^search_query) > 0.1 or
                trigram_similarity(status, ^search_query) > 0.1 or
                trigram_similarity(comments, ^search_query) > 0.3
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
                  assignee: [:user_profile],
                  vehicle: [:full_name]
                ]
              )
    end
  end

  calculations do
    calculate :status,
              :string,
              expr(
                cond do
                  start_datetime > fragment("NOW()") ->
                    "Upcoming"

                  true ->
                    if is_nil(end_datetime) or fragment("NOW()") < end_datetime do
                      "In-progress"
                    else
                      "Past"
                    end
                end
              )
  end

  preparations do
    prepare fn query, _context ->
      Ash.Query.load(query, :status)
    end
  end

  code_interface do

    define :validate_sorting_params, action: :validate_sorting_params, args: [:url_params]
    define :validate_pagination_params, action: :validate_pagination_params, args: [:url_params]
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
  end

  multitenancy do
    strategy :context
  end
end
