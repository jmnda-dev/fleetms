defmodule Fleetms.VehicleManagement.Vehicle do
  @moduledoc """
  Defines the vehicle resource.
  """
  require Ash.Query

  use Ash.Resource,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  @default_max_photo_upload_entries 10
  @default_max_document_upload_entries 10

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}
  alias Fleetms.VehicleManagement.Vehicle.Validations.MileageIsGreaterOrEqualToCurrent

  def get_max_photo_uploads, do: @default_max_photo_upload_entries
  def get_max_document_uploads, do: @default_max_document_upload_entries

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
      allow_nil? true
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
      allow_nil? true
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
    belongs_to :vehicle_model, Fleetms.VehicleManagement.VehicleModel do
      allow_nil? true
    end

    belongs_to :vehicle_group, Fleetms.VehicleManagement.VehicleGroup do
      allow_nil? true
      description "The vehicle group this vehicle belongs to."
    end

    has_one :vehicle_assignment, Fleetms.VehicleManagement.VehicleAssignment do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "The current assignment for this vehicle."
    end

    has_one :vehicle_drivetrain_spec, Fleetms.VehicleManagement.VehicleDrivetrainSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "The drivetrain information about the vehicle."
    end

    has_one :vehicle_engine_spec, Fleetms.VehicleManagement.VehicleEngineSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "The engine information about the vehicle."
    end

    has_one :vehicle_other_spec, Fleetms.VehicleManagement.VehicleOtherSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "Other related information about the vehicle."
    end

    has_one :vehicle_performance_spec, Fleetms.VehicleManagement.VehiclePerformanceSpec do
      allow_nil? true
      source_attribute :id
      destination_attribute :vehicle_id
      description "Performance related information about the vehicle."
    end

    has_many :inspection_forms, Fleetms.VehicleInspection.InspectionFormVehicle do
      domain Fleetms.VehicleInspection
    end

    has_many :service_group_vehicles, Fleetms.VehicleMaintenance.ServiceGroupVehicle do
      domain Fleetms.VehicleMaintenance
    end

    has_many :service_reminders, Fleetms.VehicleMaintenance.ServiceReminder do
      domain Fleetms.VehicleMaintenance
    end

    has_many :photos, Fleetms.VehicleManagement.VehiclePhoto
    has_many :documents, Fleetms.VehicleManagement.VehicleDocument
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

    action :get_dashboard_stats, :map do
      import Ecto.Query
      argument :tenant, :string, allow_nil?: false

      run fn input, context ->
        tenant = input.arguments.tenant

        {:ok, ecto_query} =
          Fleetms.VehicleManagement.Vehicle
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
      argument :filters, :map, default: %{}

      pagination offset?: true, countable: true

      prepare fn query, _context ->
        %{sort_order: sort_order, sort_by: sort_by} =
          query.arguments.paginate_sort_opts

        search_query = Ash.Query.get_argument(query, :search_query)
        filters = Ash.Query.get_argument(query, :filters)

        query =
          Enum.reduce(filters, query, fn
            {_key, nil}, accumulated_query ->
              accumulated_query

            {:make, vehicle_make}, accumulated_query ->
              Ash.Query.filter(
                accumulated_query,
                expr(vehicle_make == ^vehicle_make)
              )

            {:model, model_id}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(vehicle_model.id == ^model_id))

            {:mileage_min, mileage_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage >= ^mileage_min))

            {:mileage_max, mileage_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(mileage <= ^mileage_max))

            {:year_min, year_min}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(year >= ^year_min))

            {:year_max, year_max}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(year <= ^year_max))

            {:types, types}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(type in ^types))

            {:statuses, statuses}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(status in ^statuses))

            {:categories, categories}, accumulated_query ->
              Ash.Query.filter(accumulated_query, expr(category in ^categories))

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

      prepare build(load: [:vehicle_make, :model])
    end

    read :get_all do
      prepare build(load: [:full_name])
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      # TODO: Figure out a way to load these on request and not all the time
      prepare build(
                load: [
                  :num_of_photos,
                  :num_of_docs,
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

      validate MileageIsGreaterOrEqualToCurrent do
        only_when_valid? true
      end

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
            |> Fleetms.VehicleMaintenance.ServiceReminder.get_by_vehicle_id!(tenant: changeset.tenant)

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
    define :save_vehicle_documents, action: :save_vehicle_documents, args: [:documents]
    define :get_service_group_vehicles, args: [:id]
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

    count :num_of_photos, :photos, default: 0
    count :num_of_docs, :documents, default: 0
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
