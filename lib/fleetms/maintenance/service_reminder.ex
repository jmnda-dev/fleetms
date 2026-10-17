defmodule Fleetms.Maintenance.ServiceReminder do
  @moduledoc """
  Tracks when a service task is next due on a vehicle, on a mileage and/or time
  interval.

  A reminder stores where it was last completed (the vehicle's mileage and the date
  at create/reset) and, derived from that plus its intervals, the next-due mileage
  and date. How *due* it is — `:upcoming` / `:due_soon` / `:overdue` — is **not
  stored**: it's a live calculation comparing the next-due points against the
  vehicle's current mileage and today's date, so it never goes stale and needs no
  job to keep it fresh (the digest job only *notifies*). A completed work order
  will later `reset` the matching reminder, re-baselining it to "now".

  A reminder is due by mileage, by time, or both; a "due soon" lead is set per
  dimension (`mileage_threshold`, `time_threshold_days`).
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshOban, AshArchival.Resource, AshJsonApi.Resource],
    # Owner-scopes service reminders for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Maintenance

  @writable_attrs [
    :mileage_interval,
    :time_interval,
    :time_interval_unit,
    :mileage_threshold,
    :time_threshold_days
  ]

  postgres do
    table "service_reminders"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where`).
    identity_wheres_to_sql unique_vehicle_service_task: "archived_at IS NULL"

    references do
      reference :vehicle, on_delete: :delete
      reference :service_task, on_delete: :delete
      # Deleting a group's schedule line removes the reminders it generated.
      reference :service_group_schedule, on_delete: :delete
    end
  end

  permissions do
    permission :view_service_reminders,
      action: :read,
      label: "View Service Reminders",
      group: "Maintenance"

    permission :create_service_reminder,
      action: :create,
      label: "Create Service Reminder",
      group: "Maintenance"

    permission :update_service_reminder,
      action: [:update, :reset],
      label: "Update Service Reminder",
      group: "Maintenance"

    permission :delete_service_reminder,
      action: :destroy,
      label: "Delete Service Reminder",
      group: "Maintenance"
  end

  oban do
    # Run scheduled actions once per organization. The tenant (an `org_<id>` schema
    # string) is what `Fleetms.Repo.all_tenants/0` returns and is set on the action.
    list_tenants fn -> Fleetms.Repo.all_tenants() end

    scheduled_actions do
      # Every morning, email each org's owner(s) a digest of due-soon/overdue service
      # reminders. Status is derived live and already correct — the job only notifies.
      schedule :daily_service_reminder_digest, "0 7 * * *" do
        action :send_due_digest
        queue :reminder_digest
        worker_module_name Fleetms.Maintenance.ServiceReminder.Workers.DailyReminderDigest
      end
    end
  end

  # Soft delete (AshArchival): `destroy` archives the reminder. Reminders are current-
  # state operational data (not historical), so archiving hides them everywhere — from
  # the lists, the due-digest, and the group-sync's view of existing reminders (all read
  # through the default read, which the archival preparation filters). If a group still
  # mandates an archived reminder's service, the next sync just creates a fresh live one
  # (the partial index lets it past the archived row). Only `:list_archived` (the archived
  # view) opts out of the automatic filter, applying its own `not is_nil(archived_at)`.
  archive do
    exclude_read_actions([:list_archived])
  end

  json_api do
    type "service-reminder"
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    # Run per organization by AshOban: email the owner(s) a digest of the org's
    # due-soon/overdue service reminders. Returns the number of recipients emailed.
    action :send_due_digest, :integer do
      run fn _input, context ->
        Maintenance.ReminderDigest.deliver_for_tenant(context.tenant)
      end
    end

    read :get_by_id do
      get_by :id
      prepare build(load: [:due_status, :vehicle_mileage, :service_task_name, vehicle: [:name]])
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :next_due_date
        constraints one_of: [:next_due_date, :next_due_mileage, :inserted_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare Maintenance.ServiceReminder.Preparations.ListServiceReminders
    end

    # The mirror of `:list` for the archived view: only archived reminders.
    read :list_archived do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :next_due_date
        constraints one_of: [:next_due_date, :next_due_mileage, :inserted_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare Maintenance.ServiceReminder.Preparations.ListServiceReminders
    end

    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false
      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(load: [:due_status, :vehicle_mileage, :service_task_name])
    end

    create :create do
      primary? true
      accept @writable_attrs

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :service_task_id, :uuid, allow_nil?: false
      argument :service_group_schedule_id, :uuid

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
      change manage_relationship(:service_task_id, :service_task, type: :append_and_remove)

      change manage_relationship(:service_group_schedule_id, :service_group_schedule,
               type: :append_and_remove
             )

      change Maintenance.ServiceReminder.Changes.SetSchedule
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs

      argument :service_group_schedule_id, :uuid

      change manage_relationship(:service_group_schedule_id, :service_group_schedule,
               type: :append_and_remove
             )

      change Maintenance.ServiceReminder.Changes.SetSchedule
    end

    update :reset do
      description "Re-baseline the reminder to the vehicle's current mileage and today."
      require_atomic? false

      change Maintenance.ServiceReminder.Changes.SetSchedule
    end

    update :snooze do
      description "Postpone the reminder's due date by a number of days."
      require_atomic? false

      argument :days, :integer do
        allow_nil? false
        constraints min: 1
      end

      change Maintenance.ServiceReminder.Changes.Snooze
    end

    # Bring an archived reminder back into the active lists. Non-atomic: the resource's
    # interval validations can't run atomically, and there's nothing to gain here.
    update :restore do
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_service_reminders)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_service_reminder)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_service_reminder)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_service_reminder)
    end

    # Internal notifier action, invoked only by the AshOban scheduled job (no actor);
    # it reads with authorize?: false and only emails the org owner.
    policy action(:send_due_digest) do
      authorize_if always()
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
      description "Service is due every this many miles/km."
    end

    attribute :time_interval, :integer do
      public? true
      constraints min: 1, max: 999_999
      description "Service is due every this much time (in time_interval_unit)."
    end

    attribute :time_interval_unit, Maintenance.TimeUnit, public?: true

    attribute :mileage_threshold, :decimal do
      public? true
      constraints min: 0, max: 9_999_999
      description "Flag \"due soon\" this many miles/km before it falls due."
    end

    attribute :time_threshold_days, :integer do
      public? true
      constraints min: 0, max: 999_999
      description "Flag \"due soon\" this many days before it falls due."
    end

    attribute :last_completed_mileage, :decimal do
      public? true
      writable? false
      description "Vehicle mileage when the reminder was created or last reset."
    end

    attribute :last_completed_date, :date do
      public? true
      writable? false
    end

    attribute :next_due_mileage, :decimal do
      public? true
      writable? false
      description "Derived: last_completed_mileage + mileage_interval."
    end

    attribute :next_due_date, :date do
      public? true
      writable? false
      description "Derived: last_completed_date shifted by the time interval."
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :service_task, Fleetms.Maintenance.ServiceTask do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :service_group_schedule, Fleetms.Maintenance.ServiceGroupSchedule do
      allow_nil? true
      public? true
      attribute_writable? true
      description "Set when the reminder was generated by a service group."
    end
  end

  calculations do
    # How due the reminder is, computed live against the vehicle's current mileage
    # and today. Overdue if at/past next-due by either mileage or date; due soon if
    # within the per-dimension threshold; otherwise upcoming. "Whichever comes
    # first" falls out of the OR ordering (overdue wins over due_soon).
    calculate :due_status,
              Maintenance.ServiceReminderStatus,
              expr(
                cond do
                  (not is_nil(next_due_mileage) and vehicle_mileage >= next_due_mileage) or
                      (not is_nil(next_due_date) and fragment("CURRENT_DATE") >= next_due_date) ->
                    :overdue

                  (not is_nil(next_due_mileage) and
                     vehicle_mileage >=
                       next_due_mileage - fragment("coalesce(?, 0)", mileage_threshold)) or
                      (not is_nil(next_due_date) and
                         fragment("CURRENT_DATE") >=
                           fragment("? - coalesce(?, 0)::int", next_due_date, time_threshold_days)) ->
                    :due_soon

                  true ->
                    :upcoming
                end
              )

    calculate :mileage_remaining, :decimal, expr(next_due_mileage - vehicle_mileage)
    calculate :days_remaining, :integer, expr(fragment("? - CURRENT_DATE", next_due_date))
  end

  aggregates do
    first :vehicle_mileage, :vehicle, :mileage
    first :vehicle_name, :vehicle, :name
    first :service_task_name, :service_task, :name
  end

  identities do
    # Partial index: one live reminder per (vehicle, task); archived rows don't block a
    # re-synced or re-created one.
    identity :unique_vehicle_service_task, [:vehicle_id, :service_task_id] do
      where expr(is_nil(archived_at))
    end
  end
end
