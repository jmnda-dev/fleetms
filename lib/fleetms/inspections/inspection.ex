defmodule Fleetms.Inspections.Inspection do
  @moduledoc """
  A filled inspection — a driver or technician's submission of an inspection form
  against one vehicle.

  An inspection references the immutable `InspectionFormVersion` it was filled on,
  so it always renders and reads exactly as it did when taken, regardless of later
  edits to the living form. Submitting grades the answers against that version's
  schema (see `Grade`): each answer gets a status, the inspection gets an overall
  `result`, and a failure row is created for every failed item.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inspections,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshOban, AshArchival.Resource, AshJsonApi.Resource],
    # Owner-scopes inspections for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Inspections.Inspection

  postgres do
    table "inspections"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :inspection_form_version, on_delete: :nilify
      reference :inspection_form, on_delete: :nilify
      reference :submitted_by, on_delete: :nilify
    end
  end

  permissions do
    permission :view_inspections,
      action: :read,
      label: "View Inspections",
      group: "Inspections"

    permission :fill_inspections,
      action: :submit,
      label: "Fill Inspections",
      group: "Inspections"

    permission :delete_inspection,
      action: :destroy,
      label: "Delete Inspection",
      group: "Inspections"
  end

  oban do
    # Workflow jobs run once per organization; the tenant (an `org_<id>` schema
    # string, as returned by all_tenants/0) is set on the job and its action.
    list_tenants fn -> Fleetms.Repo.all_tenants() end

    triggers do
      # After an inspection is submitted, run the form's workflows against it. Fired
      # immediately via `AshOban.run_trigger` from the submit action; the once-a-minute
      # scheduler is a safety net that catches any inspection whose enqueue was lost
      # (only those still un-run — `workflows_ran_at` is nil — match).
      trigger :run_workflows do
        action :run_workflows
        # Skip archived inspections — the `:read` used to find records isn't archival-
        # filtered (Option B keeps archived inspections resolvable), so guard here.
        where expr(is_nil(workflows_ran_at) and is_nil(archived_at))
        worker_module_name Fleetms.Inspections.Inspection.Workers.RunWorkflows
        scheduler_module_name Fleetms.Inspections.Inspection.Schedulers.RunWorkflows
        queue :inspection_workflows
      end
    end
  end

  # Soft delete (AshArchival), Option B: `destroy` archives the inspection. An inspection
  # is an audit record, so it's never truly removed on a normal delete — it drops out of
  # the inspections list (see the filter on `:list`) but still resolves by id and via the
  # relationship (`:read`), so anything tracing back to it (e.g. an issue opened from one
  # of its failures) keeps working. The workflow trigger guards archived rows itself.
  archive do
    # `:list_archived` shows only archived inspections, so it opts out of the automatic
    # `is_nil(archived_at)` filter and applies its own `not is_nil(archived_at)`.
    exclude_read_actions([:read, :get_by_id, :list_archived])
  end

  json_api do
    type "inspection"

    includes(
      vehicle: [],
      inspection_form: []
    )
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id

      prepare build(
                load: [
                  :failure_count,
                  :failures,
                  vehicle: [:name],
                  inspection_form: [:title],
                  inspection_form_version: [:version_number],
                  submitted_by: [:email, profile: [:first_name, :last_name]]
                ]
              )
    end

    read :list do
      argument :vehicle_id, :uuid
      argument :inspection_form_id, :uuid
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        constraints one_of: [:submitted_at, :result, :status, :inserted_at]
        default :submitted_at
      end

      argument :sort_order, :atom do
        constraints one_of: [:asc, :desc]
        default :desc
      end

      # Browse list hides archived inspections (Option B — see the archive block).
      filter expr(
               is_nil(archived_at) and
                 if(is_nil(^arg(:vehicle_id)), do: true, else: vehicle_id == ^arg(:vehicle_id)) and
                 if(is_nil(^arg(:inspection_form_id)),
                   do: true,
                   else: inspection_form_id == ^arg(:inspection_form_id)
                 )
             )

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare Fleetms.Inspections.Inspection.Preparations.ListInspections
    end

    # The mirror of `:list` for the archived view: only archived inspections.
    read :list_archived do
      argument :vehicle_id, :uuid
      argument :inspection_form_id, :uuid
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        constraints one_of: [:submitted_at, :result, :status, :inserted_at]
        default :submitted_at
      end

      argument :sort_order, :atom do
        constraints one_of: [:asc, :desc]
        default :desc
      end

      filter expr(
               not is_nil(archived_at) and
                 if(is_nil(^arg(:vehicle_id)), do: true, else: vehicle_id == ^arg(:vehicle_id)) and
                 if(is_nil(^arg(:inspection_form_id)),
                   do: true,
                   else: inspection_form_id == ^arg(:inspection_form_id)
                 )
             )

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare Fleetms.Inspections.Inspection.Preparations.ListInspections
    end

    create :submit do
      primary? true

      argument :vehicle_id, :uuid, allow_nil?: false
      argument :inspection_form_version_id, :uuid, allow_nil?: false
      argument :answers, {:array, :map}, default: []

      change set_attribute(:vehicle_id, arg(:vehicle_id))
      change set_attribute(:inspection_form_version_id, arg(:inspection_form_version_id))
      change relate_actor(:submitted_by)
      change set_attribute(:submitted_at, &DateTime.utc_now/0)
      change Inspection.Changes.GradeAndFinalize
      change Inspection.Changes.CompleteAssignment
    end

    # Runs the form's workflows (open issues, notify) against this submitted
    # inspection. System-run by the Oban trigger, actor-less. Idempotent via the
    # `workflows_ran_at` stamp: once set, the trigger's filter no longer matches.
    update :run_workflows do
      description "Run this inspection's form workflows (background job)."
      require_atomic? false
      accept []

      change Inspection.Changes.RunWorkflows
    end

    # Bring an archived inspection back into the active list.
    update :restore do
      accept []
      change set_attribute(:archived_at, nil)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # The workflow Oban trigger reads and updates inspections with no actor; let
    # AshOban's own interactions through so it can find and process records.
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_inspections)
    end

    policy action(:submit) do
      authorize_if has_permission(:fill_inspections)
    end

    # System-run by the Oban trigger with no actor.
    policy action(:run_workflows) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_inspection)
    end

    # Restoring an archived inspection is part of managing deletions.
    policy action(:restore) do
      authorize_if has_permission(:delete_inspection)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      public? true
      allow_nil? false
      default :submitted
      writable? false
      constraints one_of: [:draft, :submitted]
    end

    attribute :result, :atom do
      public? true
      allow_nil? false
      default :pending
      writable? false
      constraints one_of: [:pending, :passed, :failed]
      description "Overall outcome, computed on submit from the graded answers."
    end

    attribute :answers, {:array, Fleetms.Inspections.Answer} do
      public? true
      allow_nil? false
      default []
    end

    attribute :submitted_at, :utc_datetime, public?: true

    attribute :workflows_ran_at, :utc_datetime do
      public? true
      writable? false

      description "When the form's workflows finished running for this inspection; nil until the Oban job completes (or set at submit when the form has no workflows)."
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :inspection_form_version, Fleetms.Inspections.InspectionFormVersion do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    # Denormalized from the version so inspections can be listed by form without a
    # join. Set by GradeAndFinalize, not user input.
    belongs_to :inspection_form, Fleetms.Inspections.InspectionForm do
      allow_nil? false
      public? true
    end

    belongs_to :submitted_by, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
    end

    has_many :failures, Fleetms.Inspections.InspectionFailure
  end

  aggregates do
    count :failure_count, :failures do
      public? true
    end
  end
end
