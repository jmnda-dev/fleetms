defmodule Fleetms.VehicleManagement.VehicleReminderPurpose do
  require Ash.Query

  use Ash.Resource,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer

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
    has_many :vehicle_general_reminders, Fleetms.VehicleManagement.VehicleGeneralReminder
  end

  actions do
    defaults [:read, :destroy, update: :*]

    action :build_upcoming_and_due_soon_reminders_query, :struct do
      run fn _input, _context ->
        # query =
        #   Ash.Query.new(__MODULE__)
        #   |> Ash.Query.filter( f)
        {:ok, __MODULE__}
      end
    end

    create :create do
      primary? true
      accept :*

      upsert? true
      upsert_fields [:name]
      upsert_identity :unique_name
    end

    read :get_all
  end

  code_interface do
    define :get_all, action: :get_all
  end

  identities do
    identity :unique_name, [:name]
  end

  postgres do
    table "vehicle_reminder_purposes"
    repo Fleetms.Repo
  end

  multitenancy do
    strategy :context
  end
end
