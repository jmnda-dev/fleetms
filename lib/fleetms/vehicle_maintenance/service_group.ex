defmodule Fleetms.VehicleMaintenance.ServiceGroup do
  use Ash.Resource,
    domain: Fleetms.VehicleMaintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :thumbnail_url, :string do
      public? true
    end

    attribute :logo, :string do
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :service_group_schedules, Fleetms.VehicleMaintenance.ServiceGroupSchedule

    many_to_many :vehicles, Fleetms.VehicleManagement.Vehicle do
      domain Fleetms.VehicleManagement
      through Fleetms.VehicleMaintenance.ServiceGroupVehicle
      source_attribute_on_join_resource :service_group_id
      destination_attribute_on_join_resource :vehicle_id
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
    table "service_groups"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept :*
      primary? true

      argument :vehicles, {:array, :uuid}, allow_nil?: true

      change manage_relationship(:vehicles, :vehicles, type: :append_and_remove)
    end

    update :update do
      accept :*
      require_atomic? false

      argument :vehicles, {:array, :uuid} do
        allow_nil? true
        default []
      end

      argument :service_group_schedules, {:array, :map}

      change manage_relationship(:vehicles, :vehicles, type: :append_and_remove)

      change fn changeset, _context ->
        if changeset.valid? do
          vehicles =
            Ash.Changeset.get_argument(changeset, :vehicles)

          service_group_schedules =
            Ash.Changeset.get_attribute(changeset, :service_group_schedules)

          if is_list(service_group_schedules) and service_group_schedules != [] do
            schedule_params =
              Enum.reduce(service_group_schedules, [], fn schedule, acc ->
                reminder_params =
                  Fleetms.VehicleMaintenance.ServiceGroupSchedule.bulk_service_reminders_attrs(
                    schedule,
                    schedule.service_tasks,
                    vehicles
                  )

                [%{"id" => schedule.id, "service_reminders" => reminder_params} | acc]
              end)

            Ash.Changeset.set_argument(
              changeset,
              :service_group_schedules,
              schedule_params
            )
          else
            changeset
          end
        else
          changeset
        end
      end

      change manage_relationship(:service_group_schedules,
               on_lookup: :ignore,
               on_no_match: :ignore,
               on_match: {:update, :update_from_service_group},
               on_missing: :ignore
             )
    end

    read :list do
      primary? true
      pagination offset?: true, default_limit: 20, countable: true

      prepare build(load: [:count_of_vehicles, :count_of_schedules])
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :vehicles,
                  service_group_schedules: [
                    :service_tasks,
                    service_reminders: [:vehicle]
                  ]
                ],
                limit: 20
              )
    end

    read :get_all
  end

  code_interface do
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :get_all, action: :get_all
  end

  identities do
    identity :unique_name, [:name]
  end

  aggregates do
    count :count_of_vehicles, :vehicles
    count :count_of_schedules, :service_group_schedules
  end

  multitenancy do
    strategy :context
  end
end
