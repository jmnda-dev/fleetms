defmodule Fleetms.Vehicles.Vehicle do
  @moduledoc """
  Defines the vehicle resource.
  """
  require Ash.Query

  use Ash.Resource,
    domain: Fleetms.Vehicles,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}
  @default_listing_limit 20
  @default_sorting_params %{sort_by: :asc, sort_order: :created_at}
  @default_paginate_params %{page: 1, per_page: @default_listing_limit}

  attributes do
    uuid_primary_key :id

    # General Information
    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 0, max_length: 30
    end

    attribute :model_code, :string do
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :category, :atom do
      public? true
      constraints one_of: Fleetms.Enums.vehicle_categories()
    end

    attribute :type, :atom do
      public? true
      allow_nil? false
      constraints one_of: Fleetms.Enums.vehicle_types()
    end

    attribute :body_style, :atom do
      public? true
      constraints one_of: Fleetms.Enums.body_style()
    end

    attribute :chassis_number, :string do
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :license_plate, :string do
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :vin, :string do
      public? true
      constraints min_length: 0, max_length: 30
    end

    attribute :year, :integer do
      public? true
      allow_nil? false
      constraints min: 1970, max: 2030
    end

    attribute :base_price, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :purchase_date, :date do
      allow_nil? true
      public? true
    end

    attribute :purchase_price, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :dealer_name, :string do
      public? true
      constraints min_length: 1, max_length: 500
    end

    attribute :color, :string do
      public? true
      constraints min_length: 0, max_length: 15
    end

    attribute :hours, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :image_url, :string do
      public? true
    end

    attribute :mileage, :decimal do
      public? true
      default 0
      constraints min: 0, max: 999_999_999
    end

    attribute :status, :atom do
      public? true
      allow_nil? false
      constraints one_of: Fleetms.Enums.vehicle_statuses()
    end

    attribute :photo, :string do
      allow_nil? true
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle_model, Fleetms.Vehicles.VehicleModel do
      allow_nil? true
    end

    belongs_to :vehicle_group, Fleetms.Vehicles.VehicleGroup do
      allow_nil? true
      description "The vehicle group this vehicle belongs to."
    end

    has_one :vehicle_assignment, Fleetms.Vehicles.VehicleAssignment do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "The current assignment for this vehicle."
    end

    has_one :vehicle_drivetrain_spec, Fleetms.Vehicles.VehicleDrivetrainSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "The drivetrain information about the vehicle."
    end

    has_one :vehicle_engine_spec, Fleetms.Vehicles.VehicleEngineSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "The engine information about the vehicle."
    end

    has_one :vehicle_other_spec, Fleetms.Vehicles.VehicleOtherSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "Other related information about the vehicle."
    end

    has_one :vehicle_performance_spec, Fleetms.Vehicles.VehiclePerformanceSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "Performance related information about the vehicle."
    end

    has_many :inspection_forms, Fleetms.Inspection.InspectionFormVehicle do
      domain Fleetms.Inspection
    end

    has_many :service_group_vehicles, Fleetms.Service.ServiceGroupVehicle do
      domain Fleetms.Service
    end

    has_many :service_reminders, Fleetms.Service.ServiceReminder do
      domain Fleetms.Service
    end

    has_many :photos, Fleetms.Vehicles.VehiclePhoto
    has_many :documents, Fleetms.Vehicles.VehicleDocument
  end

  postgres do
    table "vehicles"
    repo Fleetms.Repo
  end

  policies do
    policy action_type(:action) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:seeding) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action([
             :update,
             :save_vehicle_photos,
             :save_vehicle_documents,
             :maybe_delete_existing_photos,
             :maybe_delete_existing_documents
           ]) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
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
                name: "Name",
                vehicle_make: "Make",
                model: "Model",
                type: "Type",
                created_at: "Date Created",
                updated_at: "Date Updated",
                year: "Year",
                mileage: "Mileage"
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

      run fn input, context ->
        tenant = input.arguments.tenant

        {:ok, ecto_query} =
          Fleetms.Vehicles.Vehicle
          |> Ash.Query.set_tenant(tenant)
          |> Ash.Query.data_layer_query()

        new_ecto_query =
          from vehicle in subquery(ecto_query),
            select: %{
              total: count(vehicle.id),
              active:
                count(fragment("CASE WHEN ? = 'Active' THEN 1 ELSE NULL END", vehicle.status)),
              under_maintenance:
                count(
                  fragment("CASE WHEN ? = 'Maintenance' THEN 1 ELSE NULL END", vehicle.status)
                ),
              out_of_service:
                count(
                  fragment("CASE WHEN ? = 'Out-of-Service' THEN 1 ELSE NULL END", vehicle.status)
                )
            }

        {:ok, Fleetms.Repo.one(new_ecto_query)}
      end
    end

    create :create do
      primary? true
      accept :*

      argument :vehicle_engine_spec, :map, default: %{}
      argument :vehicle_other_spec, :map, default: %{}
      argument :vehicle_drivetrain_spec, :map, default: %{}
      argument :vehicle_performance_spec, :map, default: %{}
      argument :vehicle_model, :map

      change manage_relationship(:vehicle_engine_spec, type: :create)
      change manage_relationship(:vehicle_other_spec, type: :create)
      change manage_relationship(:vehicle_drivetrain_spec, type: :create)
      change manage_relationship(:vehicle_performance_spec, type: :create)

      change manage_relationship(:vehicle_model,
               identity_priority: [:unique_name],
               use_identities: [:unique_name],
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               on_missing: :destroy
             )
    end

    create :seeding do
      accept :*
      argument :photos, {:array, :map}
      argument :vehicle_model, :map

      argument :vehicle_engine_spec, :map, default: %{}
      argument :vehicle_other_spec, :map, default: %{}
      argument :vehicle_drivetrain_spec, :map, default: %{}
      argument :vehicle_performance_spec, :map, default: %{}
      argument :vehicle_model, :map

      change manage_relationship(:vehicle_engine_spec, type: :create)
      change manage_relationship(:vehicle_other_spec, type: :create)
      change manage_relationship(:vehicle_drivetrain_spec, type: :create)
      change manage_relationship(:vehicle_performance_spec, type: :create)
      change manage_relationship(:photos, type: :direct_control)

      change manage_relationship(:vehicle_model,
               identity_priority: [:unique_name],
               use_identities: [:unique_name],
               on_lookup: :relate_and_update,
               on_match: :update,
               on_no_match: :create,
               on_missing: :destroy
             )
    end

    update :save_vehicle_photos do
      require_atomic? false
      accept :*
      argument :photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:photos, type: :direct_control)
    end

    update :save_vehicle_documents do
      require_atomic? false
      accept :*
      argument :documents, {:array, :map}, allow_nil?: false

      change manage_relationship(:documents, type: :direct_control)
    end

    update :maybe_delete_existing_photos do
      require_atomic? false
      accept [:photo]
      argument :current_photos, {:array, :map}, allow_nil?: false

      change manage_relationship(:current_photos, :photos, type: :direct_control)
    end

    update :maybe_delete_existing_documents do
      require_atomic? false
      argument :current_documents, {:array, :map}, allow_nil?: false

      change manage_relationship(:current_documents, :documents, type: :direct_control)
    end

    read :list do
      argument :paginate_sort_opts, :map, allow_nil?: false
      argument :search_query, :string, default: ""
      argument :advanced_filter_params, :map, default: %{}

      pagination offset?: true, countable: true

      prepare fn query, _context ->
        %{sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        advanced_filter_params = Ash.Query.get_argument(query, :advanced_filter_params)

        query =
          Enum.reduce(advanced_filter_params, query, fn
            {_, "All"}, accumulated_query ->
              accumulated_query

            {_, :All}, accumulated_query ->
              accumulated_query

            {:vehicle_make, vehicle_make}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_make == ^vehicle_make))

            {:model, model}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(model == ^model))

            {:mileage_min, mileage_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage >= ^mileage_min))

            {:mileage_max, mileage_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage <= ^mileage_max))

            {:year_from, year_from}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(year >= ^year_from))

            {:year_to, year_to}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(year <= ^year_to))

            {:type, vehicle_type}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(type == ^vehicle_type))

            {:status, vehicle_status}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(status == ^vehicle_status))

            {:category, vehicle_category}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(status == ^vehicle_category))

            _, accumulated_query ->
              accumulated_query
          end)
          |> Ash.Query.sort([{sort_by, sort_order}])

        if search_query == "" or is_nil(search_query) do
          query
        else
          Ash.Query.filter(
            query,
            expr(
              trigram_similarity(name, ^search_query) > 0.1 or
                trigram_similarity(vehicle_model.vehicle_make.name, ^search_query) > 0.1 or
                trigram_similarity(vehicle_model.name, ^search_query) > 0.1 or
                trigram_similarity(license_plate, ^search_query) > 0.1 or
                trigram_similarity(vin, ^search_query) > 0.3 or
                trigram_similarity(type, ^search_query) > 0.1
            )
          )
        end
      end
    end

    read :get_all do
      prepare build(load: [:full_name])
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :photos,
                  :documents,
                  :vehicle_engine_spec,
                  :vehicle_drivetrain_spec,
                  :vehicle_other_spec,
                  :vehicle_performance_spec,
                  :vehicle_make,
                  vehicle_model: [:vehicle_make]
                ]
              )
    end

    read :get_service_group_vehicles do
      argument :id, :uuid, allow_nil?: false

      filter expr(service_group_vehicles.service_group_id == ^arg(:id))
      pagination offset?: true, default_limit: 10, countable: true
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :vehicle_engine_spec, :map, default: %{}
      argument :vehicle_other_spec, :map, default: %{}
      argument :vehicle_drivetrain_spec, :map, default: %{}
      argument :vehicle_performance_spec, :map, default: %{}
      argument :service_reminders, {:array, :map}
      argument :vehicle_model, :map

      change manage_relationship(:vehicle_engine_spec, type: :direct_control)
      change manage_relationship(:vehicle_other_spec, type: :direct_control)
      change manage_relationship(:vehicle_drivetrain_spec, type: :direct_control)
      change manage_relationship(:vehicle_performance_spec, type: :direct_control)

      change manage_relationship(:vehicle_model,
               identity_priority: [:unique_name],
               use_identities: [:unique_name],
               on_lookup: :relate_and_update,
               on_match: :ignore,
               on_no_match: :create,
               on_missing: :destroy
             )

      change fn changeset, _context ->
        if Ash.Changeset.changing_attribute?(changeset, :mileage) do
          service_reminders =
            changeset
            |> Ash.Changeset.get_attribute(:id)
            |> Fleetms.Service.ServiceReminder.get_by_vehicle_id!(tenant: changeset.tenant)

          mileage = Ash.Changeset.get_attribute(changeset, :mileage)

          reminder_params =
            Enum.map(
              service_reminders,
              &%{"id" => &1.id, "vehicle_id" => &1.vehicle_id, "vehicle_mileage" => mileage}
            )

          Ash.Changeset.set_argument(changeset, :service_reminders, reminder_params)
        else
          changeset
        end
      end

      change manage_relationship(:service_reminders,
               on_no_match: :ignore,
               on_match: {:update, :update_from_vehicle},
               on_missing: :ignore
             )
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_vehicle ->
          # Here, I access photos to delete by calling `deleted_vehicle.photos` because `photos` is already loaded when the
          # Vehicle to delete was queried with `get_by_id/1` and passed to `Ash.destroy` in the FleetmsWeb.VehicleLive.List LiveView.
          # If calling this action from somewhere else, make sure `photos` is loaded otherwise this action will fail.
          Enum.map(deleted_vehicle.photos, fn
            vehicle_photo ->
              Fleetms.VehiclePhoto.delete({vehicle_photo.filename, deleted_vehicle})
          end)

          {:ok, deleted_vehicle}
        end)
      end
    end
  end

  code_interface do
    define :get_all, action: :get_all
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :save_vehicle_photos, action: :save_vehicle_photos, args: [:photos]
    define :save_vehicle_documents, action: :save_vehicle_documents, args: [:photos]
    define :get_service_group_vehicles, args: [:id]
    define :validate_sorting_params, action: :validate_sorting_params, args: [:url_params]
    define :validate_pagination_params, action: :validate_pagination_params, args: [:url_params]
    define :get_dashboard_stats, action: :get_dashboard_stats, args: [:tenant]
  end

  preparations do
    prepare build(load: [:full_name])
  end

  aggregates do
    first :vehicle_make, [:vehicle_model, :vehicle_make], :name do
      filterable? true
    end

    first :model, :vehicle_model, :name do
      filterable? true
    end
  end

  calculations do
    calculate :full_name,
              :string,
              expr(vehicle_make <> " " <> model <> " - " <> "[" <> name <> "]")
  end

  multitenancy do
    strategy :context
  end
end
