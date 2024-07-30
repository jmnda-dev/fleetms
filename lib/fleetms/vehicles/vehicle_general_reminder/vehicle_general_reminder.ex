defmodule Fleetms.Vehicles.VehicleGeneralReminder do
  use Ash.Resource,
    domain: Fleetms.Vehicles,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query
  require Ash.Resource.Change.Builtins

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}

  attributes do
    uuid_primary_key :id

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
    end

    attribute :time_interval, :decimal do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :time_interval_unit, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.time_units()
    end

    attribute :due_date_threshold, :integer do
      allow_nil? true
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :due_date_threshold_unit, :atom do
      allow_nil? true
      public? true
      constraints one_of: Fleetms.Enums.time_units()
    end

    attribute :last_completed_date, :date do
      allow_nil? true
      public? true
      writable? false
    end

    attribute :due_status, :atom do
      allow_nil? false
      public? true
      writable? false
      constraints one_of: Fleetms.Enums.general_reminder_statuses()
    end

    attribute :due_date, :date do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.Vehicles.Vehicle do
      allow_nil? false
    end

    belongs_to :vehicle_reminder_purpose, Fleetms.Vehicles.VehicleReminderPurpose do
      allow_nil? false
    end
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
    end

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end
  end

  postgres do
    table "vehicle_general_reminders"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :vehicle_reminder_purpose, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      argument :vehicle_id, :uuid do
        allow_nil? false
      end

      argument :vehicle_reminder_purpose, :map do
        allow_nil? false
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:vehicle_reminder_purpose, type: :direct_control)

      change Fleetms.Vehicles.VehicleGeneralReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    create :ignore_create

    update :update do
      primary? true
      require_atomic? false
      accept :*

      argument :vehicle_id, :uuid do
        allow_nil? false
      end

      argument :vehicle_reminder_purpose, :map do
        allow_nil? false
      end

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:vehicle_reminder_purpose, type: :direct_control)

      change Fleetms.Vehicles.VehicleGeneralReminder.Changes.SetStatus do
        only_when_valid? true
      end
    end

    read :list do
      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      pagination offset?: true, default_limit: 50, countable: true

      prepare fn query, _context ->
        %{sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        advanced_filter_params = Ash.Query.get_argument(query, :advanced_filter_params)

        # TODO: Rearange these queries, start with search then filters, then sort
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

            {:due_statuses, statuses}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(due_status in ^statuses))

            {:time_interval_min, time_interval_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(time_interval >= ^time_interval_min))

            {:time_interval_max, time_interval_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(time_interval <= ^time_interval_max))

            {:time_interval_unit, time_interval_unit}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(time_interval_unit == ^time_interval_unit))

            {:due_date_from, due_date_from}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(due_date >= ^due_date_from))

            {:due_date_to, due_date_to}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(due_date <= ^due_date_to))

            {:vehicles, vehicle_ids}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_id in ^vehicle_ids))

            _, accumulated_query ->
              accumulated_query
          end)
          |> Ash.Query.sort([{sort_by, sort_order}])
          |> Ash.Query.load([
            :reminder_purpose_name,
            :vehicle_name,
            vehicle: [:full_name]
          ])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(vehicle.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle.vehicle_model.vehicle_make.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle_reminder_purpose.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle_reminder_purpose.description, ^search_query) > 0.1 or
                trigram_similarity(description, ^search_query) > 0.1
            )
          )
        end
      end
    end

    read :get_all

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      prepare build(
                load: [
                  :vehicle_reminder_purpose,
                  vehicle: [:full_name]
                ]
              )

      filter expr(id == ^arg(:id))
    end
  end

  code_interface do
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
  end

  identities do
    identity :unique_vehicle_general_reminder, [:vehicle_id, :vehicle_reminder_purpose_id],
      eager_check_with: Fleetms.Vehicles
  end

  aggregates do
    first :vehicle_name, :vehicle, :name
    first :reminder_purpose_name, :vehicle_reminder_purpose, :name
  end

  multitenancy do
    strategy :context
  end
end
