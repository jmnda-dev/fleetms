defmodule Fleetms.FuelTracking.FuelHistory do
  require Ash.Query

  use Ash.Resource,
    domain: Fleetms.FuelTracking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager, IsTechnician}

  require Ash.Query

  @default_listing_limit 20
  @default_sorting_params %{sort_by: :desc, sort_order: :created_at}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}

  attributes do
    uuid_primary_key :id

    attribute :odometer_reading, :decimal do
      allow_nil? false
      public? true
      constraints min: 0, max: 999_999_999.99
    end

    attribute :refuel_datetime, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :refuel_quantity, :decimal do
      allow_nil? false
      public? true
      constraints min: 0, max: 999_999_999.99
    end

    attribute :refuel_cost, AshMoney.Types.Money do
      public? true
      allow_nil? false
    end

    attribute :refuel_location, :string do
      public? true
      allow_nil? true
      constraints min_length: 1, max_length: 255
    end

    attribute :fuel_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: Fleetms.Enums.fuel_tracking_fuel_types()
    end

    attribute :payment_method, :atom do
      allow_nil? false
      public? true
      constraints one_of: Fleetms.Enums.fuel_tracking_payment_methods()
    end

    attribute :notes, :string do
      allow_nil? true
      public? true
      constraints max_length: 1000
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.Vehicles.Vehicle do
      allow_nil? false
      domain Fleetms.Vehicles
    end

    belongs_to :refueled_by, Fleetms.Accounts.User do
      allow_nil? true
      domain Fleetms.Accounts
      source_attribute :refueled_by_id
      destination_attribute :id
    end

    has_many :fuel_history_photos, Fleetms.FuelTracking.FuelHistoryPhoto
  end

  policies do
    policy action_type(:action) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if IsTechnician
      authorize_if IsDriver
    end

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
      authorize_if relates_to_actor_via(:refueled_by)
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action([:save_fuel_history_photos, :maybe_delete_existing_photos]) do
      authorize_if always()
    end
  end

  postgres do
    table "fuel_histories"
    repo Fleetms.Repo

    references do
      reference(:vehicle, on_delete: :delete)
      reference(:refueled_by, on_delete: :nilify)
    end
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
                refuel_datetime: "Date and Time of Refuel",
                odometer_reading: "Odometer Reading",
                refuel_quantity: "Refuel Quantity",
                refuel_cost: "Refuel Cost",
                fuel_type: "Fuel Type",
                payment_method: "Payment Method",
                created_at: "Date Created",
                updated_at: "Date Updated"
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

    action :get_dashboard_stats, {:array, :map} do
      argument :tenant, :string, allow_nil?: false

      argument :period, :atom,
        allow_nil?: false,
        constraints: [one_of: [:seven_days, :thirty_days, :twelve_months]]

      run fn input, context ->
        tenant = input.arguments.tenant
        period = input.arguments.period

        today = Date.utc_today()

        {start_date, end_date} =
          case period do
            :seven_days ->
              {Timex.shift(today, days: -7), today}

            :thirty_days ->
              {Timex.shift(today, days: -30), today}

            :twelve_months ->
              {Timex.shift(today, months: -12), today}
          end

        new_ecto_query =
          fuel_history_stats_query(tenant, period, start_date, end_date)

        {:ok, Fleetms.Repo.all(new_ecto_query)}
      end
    end

    create :create do
      primary? true
      accept :*

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :refueled_by_id, :uuid

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:refueled_by_id, :refueled_by, type: :append_and_remove)
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :refueled_by_id, :uuid

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:refueled_by_id, :refueled_by, type: :append_and_remove)
    end

    update :save_fuel_history_photos do
      require_atomic? false
      argument :fuel_history_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:fuel_history_photos, type: :direct_control)
    end

    update :maybe_delete_existing_photos do
      require_atomic? false
      argument :current_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:current_photos, :fuel_history_photos, type: :direct_control)
    end

    read :list do
      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      pagination offset?: true, default_limit: 50, countable: true

      prepare fn query, _context ->
        %{page: page, per_page: per_page, sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        advanced_filter_params = Ash.Query.get_argument(query, :advanced_filter_params)

        query =
          Enum.reduce(advanced_filter_params, query, fn
            {_, nil}, accumulated_query ->
              accumulated_query

            {_, "All"}, accumulated_query ->
              accumulated_query

            {_, :All}, accumulated_query ->
              accumulated_query

            {:odometer_reading_min, odometer_reading_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(odometer_reading >= ^odometer_reading_min))

            {:odometer_reading_max, odometer_reading_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(odometer_reading <= ^odometer_reading_max))

            {:refuel_date_from, refuel_date_from}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(refuel_datetime >= ^refuel_date_from))

            {:refuel_date_to, refuel_date_to}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(refuel_datetime <= ^refuel_date_to))

            {:refuel_quantity_min, refuel_quantity_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(refuel_quantity >= ^refuel_quantity_min))

            {:refuel_quantity_max, refuel_quantity_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(refuel_quantity <= ^refuel_quantity_max))

            {:refuel_cost_min, refuel_cost_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(refuel_cost >= ^refuel_cost_min))

            {:refuel_cost_max, refuel_cost_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(refuel_cost <= ^refuel_cost_max))

            {:vehicles, vehicles}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_id in ^vehicles))

            {:refueled_by, refueled_by_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(refueled_by_id in ^refueled_by_ids))

            {:fuel_types, fuel_types}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(fuel_type in ^fuel_types))

            {:payment_methods, payment_methods}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(payment_method in ^payment_methods))

            _, accumulated_query ->
              accumulated_query
          end)
          |> Ash.Query.sort([{sort_by, sort_order}])
          |> Ash.Query.load(
            refueled_by: [user_profile: :full_name],
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
                trigram_similarity(refueled_by.user_profile.first_name, ^search_query) > 0.3 or
                trigram_similarity(refueled_by.user_profile.last_name, ^search_query) > 0.3 or
                trigram_similarity(payment_method, ^search_query) > 0.3 or
                trigram_similarity(fuel_type, ^search_query) > 0.3 or
                trigram_similarity(refuel_location, ^search_query) > 0.3
            )
          )
        end
      end
    end

    read :list_vehicle_fuel_histories do
      argument :vehicle_id, :uuid, allow_nil?: false

      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(load: [refueled_by: [user_profile: :full_name]])
      pagination offset?: true, default_limit: 50, countable: true
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :fuel_history_photos,
                  refueled_by: [user_profile: :full_name],
                  vehicle: [:full_name]
                ]
              )
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_fuel_history ->
          # Here, I access photos to delete by calling `deleted_fuel_history.fuel_history_photos` because `fuel_history_photos` relationship is already loaded when the
          # FuelHistory to delete was queried with `get_by_id/1` and passed to `Ash.destroy` in the FleetmsWeb.FuelHistoryLive.Index LiveView.
          # If calling this action from somewhere else, make sure `fuel_history_photos` is loaded otherwise this action will fail.
          Enum.map(deleted_fuel_history.fuel_history_photos, fn
            fuel_history_photo ->
              Fleetms.FuelHistoryPhoto.delete({fuel_history_photo.filename, deleted_fuel_history})
          end)

          {:ok, deleted_fuel_history}
        end)
      end
    end
  end

  code_interface do

    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :validate_sorting_params, action: :validate_sorting_params, args: [:url_params]
    define :validate_pagination_params, action: :validate_pagination_params, args: [:url_params]
    define :save_fuel_history_photos, action: :save_fuel_history_photos, args: [:issue_photos]
    define :get_dashboard_stats, action: :get_dashboard_stats, args: [:tenant, :period]
  end

  multitenancy do
    strategy :context
  end

  defp fuel_history_stats_query(tenant, period, start_date, end_date) do
    import Ecto.Query

    {:ok, fuel_history_query} =
      Fleetms.FuelTracking.FuelHistory
      |> Ash.Query.new()
      |> Ash.Query.set_tenant(tenant)
      |> Ash.Query.data_layer_query()

    if period in [:seven_days, :thirty_days] do
      from(
        dates in fragment(
          "SELECT generate_series((?)::date, (?)::date, '1 day'::interval) AS duration",
          ^start_date,
          ^end_date
        ),
        join: fuel_history in subquery(fuel_history_query),
        as: :fuel_history,
        on: true,
        group_by: dates.duration,
        order_by: dates.duration,
        select: %{
          duration:
            fragment(
              "CONCAT(SUBSTRING(trim(TO_CHAR(?, 'Day')), 1, 3), ' ', SUBSTRING(trim(TO_CHAR(?, 'Month')), 1, 3), ' ', EXTRACT(day FROM ?)::integer)",
              dates.duration,
              dates.duration,
              dates.duration
            ),
          total_cost:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration)
            |> coalesce(0),
          total_quantity:
            sum(fuel_history.refuel_quantity)
            |> filter(fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration)
            |> coalesce(0),
          total_cost_diesel:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(
              fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration and
                fuel_history.fuel_type == :Diesel
            )
            |> coalesce(0),
          total_quantity_diesel:
            sum(fuel_history.refuel_quantity)
            |> filter(
              fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration and
                fuel_history.fuel_type == :Diesel
            )
            |> coalesce(0),
          total_cost_gasoline:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(
              fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration and
                fuel_history.fuel_type == :Gasoline
            )
            |> coalesce(0),
          total_quantity_gasoline:
            sum(fuel_history.refuel_quantity)
            |> filter(
              fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration and
                fuel_history.fuel_type == :Gasoline
            )
            |> coalesce(0),
          total_cost_other:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(
              fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration and
                fuel_history.fuel_type not in [:Diesel, :Gasoline]
            )
            |> coalesce(0),
          total_quantity_other:
            sum(fuel_history.refuel_quantity)
            |> filter(
              fragment("DATE(?)", fuel_history.refuel_datetime) == dates.duration and
                fuel_history.fuel_type not in [:Diesel, :Gasoline]
            )
            |> coalesce(0)
        }
      )
    else
      from(
        dates in fragment(
          "SELECT generate_series((?)::date, (?)::date, '1 month'::interval) AS duration",
          ^start_date,
          ^end_date
        ),
        join: fuel_history in subquery(fuel_history_query),
        as: :fuel_history,
        on: true,
        group_by: dates.duration,
        order_by: dates.duration,
        select: %{
          duration:
            fragment(
              "CONCAT(SUBSTRING(trim(TO_CHAR(?, 'Month')), 1, 3), ' ', trim(TO_CHAR(?, 'YYYY')))",
              dates.duration,
              dates.duration
            ),
          total_cost:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration)
            )
            |> coalesce(0),
          total_quantity:
            sum(fuel_history.refuel_quantity)
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration)
            )
            |> coalesce(0),
          total_cost_diesel:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                fuel_history.fuel_type == :Diesel
            )
            |> coalesce(0),
          total_quantity_diesel:
            sum(fuel_history.refuel_quantity)
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                fuel_history.fuel_type == :Diesel
            )
            |> coalesce(0),
          total_cost_gasoline:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                fuel_history.fuel_type == :Gasoline
            )
            |> coalesce(0),
          total_quantity_gasoline:
            sum(fuel_history.refuel_quantity)
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                fuel_history.fuel_type == :Gasoline
            )
            |> coalesce(0),
          total_cost_other:
            sum(fragment("amount(?)", fuel_history.refuel_cost))
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                fuel_history.fuel_type not in [:Diesel, :Gasoline]
            )
            |> coalesce(0),
          total_quantity_other:
            sum(fuel_history.refuel_quantity)
            |> filter(
              fragment("TO_CHAR(DATE(?), 'YYYY-MM')", fuel_history.refuel_datetime) ==
                fragment("TO_CHAR(?, 'YYYY-MM')", dates.duration) and
                fuel_history.fuel_type not in [:Diesel, :Gasoline]
            )
            |> coalesce(0)
        }
      )
    end
  end
end
