defmodule Fleetms.Maintenance.ServiceGroupSchedule do
  @moduledoc """
  One line of a service group's programme: a service task plus the mileage/time
  intervals at which it recurs. A group is a set of these lines applied to a set of
  vehicles; each (schedule line × member vehicle) becomes a `ServiceReminder` kept
  in sync by the group.

  The interval/threshold fields mirror `ServiceReminder` — they're the template the
  generated reminders are stamped from. Managed through the parent service group
  (`type: :direct_control`).
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Fleetms.Maintenance

  @interval_attrs [
    :mileage_interval,
    :time_interval,
    :time_interval_unit,
    :mileage_threshold,
    :time_threshold_days
  ]

  postgres do
    table "service_group_schedules"
    repo Fleetms.Repo

    references do
      reference :service_group, on_delete: :delete
      reference :service_task, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    create :create do
      primary? true
      accept @interval_attrs

      argument :service_task_id, :uuid, allow_nil?: false

      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false
      accept @interval_attrs

      argument :service_task_id, :uuid

      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if accessing_from(Fleetms.Maintenance.ServiceGroup, :schedules)
    end
  end

  validations do
    validate present([:mileage_interval, :time_interval], at_least: 1) do
      message "Set a mileage interval, a time interval, or both."
    end

    validate present(:time_interval_unit) do
      where present(:time_interval)
      message "Pick a unit for the time interval."
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :mileage_interval, :decimal do
      public? true
      constraints min: 1, max: 9_999_999
    end

    attribute :time_interval, :integer do
      public? true
      constraints min: 1, max: 999_999
    end

    attribute :time_interval_unit, Maintenance.TimeUnit, public?: true

    attribute :mileage_threshold, :decimal do
      public? true
      constraints min: 0, max: 9_999_999
    end

    attribute :time_threshold_days, :integer do
      public? true
      constraints min: 0, max: 999_999
    end

    timestamps()
  end

  relationships do
    belongs_to :service_group, Fleetms.Maintenance.ServiceGroup do
      allow_nil? false
    end

    belongs_to :service_task, Fleetms.Maintenance.ServiceTask do
      allow_nil? false
      public? true
    end

    has_many :service_reminders, Fleetms.Maintenance.ServiceReminder
  end

  aggregates do
    first :service_task_name, :service_task, :name
  end
end
