defmodule Fleetms.VehicleManagement.VehicleRenewal do
  @moduledoc """
  A date-based recurring reminder for a vehicle — insurance, roadworthiness,
  registration, and the like. Distinct from the usage/time-based *service*
  reminders that Maintenance will add.

  Each renewal has a `due_date`, an optional recurrence (how often it renews) and
  an optional "notify before" lead time. Its `status` (Upcoming / Due Soon /
  Overdue) is a **derived calculation**, not a stored, worker-maintained column:
  we store `notify_from_date` (when "Due Soon" begins, computed at write time with
  exact calendar math) so the status is a pure date comparison that is always
  correct without anything running as time passes. The scheduled job (added later)
  only sends notifications; it is not the source of truth for status.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshOban, AshArchival.Resource, AshJsonApi.Resource],
    # Owner-scopes renewals for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  # Soft delete (AshArchival): `destroy` archives instead of removing the row, so a
  # renewal deleted by mistake can be recovered. Archived rows are filtered out of
  # reads by AshArchival's default read preparation.

  alias Fleetms.VehicleManagement

  @writable_attrs [
    :due_date,
    :comments,
    :recurrence_interval,
    :recurrence_unit,
    :notify_before,
    :notify_before_unit,
    :vehicle_id,
    :renewal_type_id
  ]

  postgres do
    table "vehicle_renewals"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where` below).
    identity_wheres_to_sql unique_vehicle_renewal_type: "archived_at IS NULL"

    references do
      reference :vehicle, on_delete: :delete
      reference :renewal_type, on_delete: :nothing
    end
  end

  permissions do
    permission :view_renewals,
      action: :read,
      label: "View Renewals",
      group: "Renewals"

    permission :create_renewal,
      action: :create,
      label: "Create Renewal",
      group: "Renewals"

    permission :update_renewal,
      action: [:update, :mark_renewed],
      label: "Update Renewal",
      group: "Renewals"

    permission :delete_renewal,
      action: :destroy,
      label: "Delete Renewal",
      group: "Renewals"
  end

  oban do
    # Run scheduled actions once per organization. The tenant (an `org_<id>` schema
    # string) is what `Fleetms.Repo.all_tenants/0` returns and is set on the action.
    list_tenants fn -> Fleetms.Repo.all_tenants() end

    scheduled_actions do
      # Every morning, email each org's owner(s) a digest of due-soon/overdue
      # renewals. Status is already correct without this — the job only notifies.
      schedule :daily_renewal_digest, "0 7 * * *" do
        action :send_due_digest
        queue :renewal_digest
        worker_module_name Fleetms.VehicleManagement.VehicleRenewal.Workers.DailyRenewalDigest
      end
    end
  end

  # Soft delete (AshArchival): `destroy` archives the renewal. Renewals are current-state
  # operational data, so archiving hides them everywhere — every read is auto-filtered.
  # Only `:list_archived` (the archived view) opts out, applying `not is_nil(archived_at)`.
  archive do
    exclude_read_actions([:list_archived])
  end

  json_api do
    type "vehicle-renewal"
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :due_date
        constraints one_of: [:due_date, :status, :inserted_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare VehicleManagement.VehicleRenewal.Preparations.ListRenewals
    end

    # The mirror of `:list` for the archived view: only archived renewals.
    read :list_archived do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :due_date
        constraints one_of: [:due_date, :status, :inserted_at]
      end

      argument :sort_order, :atom do
        default :asc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare VehicleManagement.VehicleRenewal.Preparations.ListRenewals
    end

    create :create do
      primary? true
      accept @writable_attrs

      validate VehicleManagement.VehicleRenewal.Validations.PairedIntervalUnits
      change VehicleManagement.VehicleRenewal.Changes.SetNotifyFromDate
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs

      validate VehicleManagement.VehicleRenewal.Validations.PairedIntervalUnits
      change VehicleManagement.VehicleRenewal.Changes.SetNotifyFromDate
    end

    update :mark_renewed do
      description "Record that the renewal was completed and roll it forward one cycle."
      require_atomic? false

      validate present([:recurrence_interval, :recurrence_unit]) do
        message "this renewal has no recurrence to roll forward"
      end

      change VehicleManagement.VehicleRenewal.Changes.AdvanceDueDate
      change VehicleManagement.VehicleRenewal.Changes.SetNotifyFromDate
    end

    # Bring an archived renewal back into the active lists. Non-atomic: an atomic update
    # would re-read through the archival-filtered primary read and miss the archived row.
    update :restore do
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end

    destroy :destroy do
      primary? true
    end

    # Run per organization by AshOban: email the owner(s) a digest of the org's
    # due-soon/overdue renewals. Returns the number of recipients emailed.
    action :send_due_digest, :integer do
      run fn _input, context ->
        VehicleManagement.RenewalDigest.deliver_for_tenant(context.tenant)
      end
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_renewals)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_renewal)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_renewal)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_renewal)
    end

    # Internal notifier action, invoked only by the AshOban scheduled job (no actor);
    # it reads with authorize?: false and only emails the org owner.
    policy action(:send_due_digest) do
      authorize_if always()
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :due_date, :date do
      allow_nil? false
      public? true
      description "When this renewal is next due."
    end

    attribute :comments, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :recurrence_interval, :integer do
      public? true
      constraints min: 1, max: 999_999
      description "How many recurrence units between renewals (e.g. 1)."
    end

    attribute :recurrence_unit, VehicleManagement.TimeUnit do
      public? true
      description "Unit for the recurrence interval (e.g. years)."
    end

    attribute :notify_before, :integer do
      public? true
      constraints min: 1, max: 999_999
      description "How far ahead of the due date to start flagging \"Due Soon\"."
    end

    attribute :notify_before_unit, VehicleManagement.TimeUnit, public?: true

    attribute :notify_from_date, :date do
      public? true
      writable? false
      description "Computed: the date \"Due Soon\" begins (due_date minus the lead time)."
    end

    attribute :last_completed_date, :date do
      public? true
      writable? false
      description "When the renewal was last marked as completed."
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :renewal_type, Fleetms.VehicleManagement.RenewalType do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  calculations do
    # Derived from the stored dates — always correct, no worker keeps it in sync.
    calculate :status,
              :string,
              expr(
                cond do
                  today() >= due_date -> "Overdue"
                  not is_nil(notify_from_date) and today() >= notify_from_date -> "Due Soon"
                  true -> "Upcoming"
                end
              )
  end

  identities do
    # Partial unique index: uniqueness applies only among non-archived rows, so a
    # renewal can be recreated for the same vehicle + type after the old one is
    # archived (the archived row no longer occupies the slot).
    identity :unique_vehicle_renewal_type, [:vehicle_id, :renewal_type_id] do
      where expr(is_nil(archived_at))
    end
  end
end
