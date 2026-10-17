defmodule Fleetms.VehicleIssues.Issue do
  @moduledoc """
  A fault or task raised against a vehicle — the entry point to maintenance.

  An issue carries identifying/triage information (number, title, description,
  priority, tags, the meter readings when it was reported) and moves through a
  small lifecycle managed by `AshStateMachine`: `open → resolved → closed`, with
  the ability to reopen. Lifecycle transitions are explicit actions
  (`resolve`/`close`/`reopen`) rather than free-form status edits, so each one can
  stamp its own timestamp and capture comments, and illegal jumps are rejected.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleIssues,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      Fleetms.Permissions.Dsl,
      AshStateMachine,
      AshArchival.Resource,
      AshPaperTrail.Resource,
      AshJsonApi.Resource
    ],
    # Owner-scopes issues for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  postgres do
    table "issues"
    repo Fleetms.Repo

    # SQL for the partial unique index (see the identity's `where`).
    identity_wheres_to_sql unique_issue_number: "archived_at IS NULL"

    references do
      reference :vehicle, on_delete: :delete
      reference :assigned_to, on_delete: :nilify
      reference :reported_by, on_delete: :nothing
      # Unlink (don't delete) issues if the work order they were attached to is deleted.
      reference :work_order, on_delete: :nilify
    end

    # Per-tenant sequence backing `issue_number`. `code? true` so the statement is
    # emitted as migration code and can schema-qualify with `prefix()` — otherwise
    # the raw SQL runs against the default search_path and the sequence lands in
    # `public`, shared across all orgs. The schema is double-quoted because tenant
    # schema names contain hyphens. Drawn from in `Changes.SetIssueNumber`.
    custom_statements do
      statement :issue_number_sequence do
        code? true
        up ~S|execute("CREATE SEQUENCE IF NOT EXISTS \"#{prefix()}\".issues_number_seq")|
        down ~S|execute("DROP SEQUENCE IF EXISTS \"#{prefix()}\".issues_number_seq")|
      end
    end
  end

  import Fleetms.Permissions, only: [has_permission: 1]

  permissions do
    permission :view_issues,
      action: :read,
      label: "View Issues",
      group: "Issues"

    permission :create_issue,
      action: :create,
      label: "Create Issue",
      group: "Issues"

    permission :update_issue,
      action: [:update, :resolve, :close, :reopen],
      label: "Update Issue",
      group: "Issues"

    permission :delete_issue,
      action: :destroy,
      label: "Delete Issue",
      group: "Issues"
  end

  alias Fleetms.VehicleIssues

  # Attributes accepted by both create and update (the lifecycle fields — status,
  # resolved_at, closed_at, comments — are set only by their transition actions).
  @writable_attrs [
    :title,
    :description,
    :priority,
    :reported_at,
    :due_date,
    :mileage,
    :hours,
    :vehicle_id,
    :assigned_to_id
  ]

  state_machine do
    initial_states [:open]
    default_initial_state :open
    state_attribute :status

    transitions do
      transition :resolve, from: [:open], to: :resolved
      transition :close, from: [:open, :resolved], to: :closed
      transition :reopen, from: [:resolved, :closed], to: :open
    end
  end

  # Soft delete (AshArchival), Option B: `destroy` archives the issue — keeping its
  # photos/documents and their stored files, so it can be recovered. Archived issues
  # are hidden from the browse lists (see the filters on `:list` / `:list_by_vehicle`)
  # but still resolve where an inspection failure links to one, and via `get_by_id`.
  # `:purge` is the true hard delete that also removes the stored files, and is
  # excluded from archival so it really deletes.
  archive do
    exclude_destroy_actions([:purge])
    # `:list_archived` shows only archived issues, so it opts out of the automatic
    # `is_nil(archived_at)` filter and applies its own `not is_nil(archived_at)`.
    exclude_read_actions([:read, :get_by_id, :list_archived])
  end

  # Audit trail (AshPaperTrail): every create/update/destroy writes an `issue_versions`
  # row (in the tenant schema) with the acting user, the action name, and a full diff of
  # what changed. The History tab derives a readable timeline from these.
  paper_trail do
    change_tracking_mode(:full_diff)
    store_action_name?(true)
    reference_source?(false)
    ignore_attributes([:inserted_at, :updated_at])
    belongs_to_actor(:user, Fleetms.Accounts.User, domain: Fleetms.Accounts)
  end

  json_api do
    type "issue"
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
        default :issue_number
        constraints one_of: [:issue_number, :title, :priority, :status, :due_date, :reported_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      # Browse list hides archived issues (Option B — see the archive block).
      filter expr(is_nil(archived_at))
      prepare VehicleIssues.Issue.Preparations.ListIssues
    end

    # The mirror of `:list` for the archived view: only archived issues.
    read :list_archived do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :issue_number
        constraints one_of: [:issue_number, :title, :priority, :status, :due_date, :reported_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare VehicleIssues.Issue.Preparations.ListIssues
    end

    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false
      filter expr(vehicle_id == ^arg(:vehicle_id) and is_nil(archived_at))
      prepare build(sort: [issue_number: :desc])
    end

    create :create do
      primary? true
      accept @writable_attrs
      argument :tags, {:array, :string}

      change relate_actor(:reported_by)
      change VehicleIssues.Issue.Changes.SetIssueNumber
      change {VehicleIssues.Changes.SanitizeHtml, attributes: [:description]}

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )

      change VehicleIssues.Issue.Changes.NotifyAssignee
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs
      argument :tags, {:array, :string}

      change {VehicleIssues.Changes.SanitizeHtml, attributes: [:description]}

      change manage_relationship(:tags,
               type: :append_and_remove,
               on_no_match: :create,
               on_match: :ignore,
               use_identities: [:unique_name],
               value_is_key: :name
             )

      change VehicleIssues.Issue.Changes.NotifyAssignee
    end

    # (Un)link this issue to a work order — a pure association, with none of the
    # update action's notifications. Used by WorkOrder's `issue_ids` management.
    # Non-atomic because writing an audit version (AshPaperTrail) can't be atomic, and
    # this runs inside the work order's managed-relationship update.
    update :link_to_work_order do
      require_atomic? false
      accept []
    end

    update :resolve do
      description "Mark the issue resolved, optionally noting how."
      require_atomic? false
      accept [:resolve_comments]

      change transition_state(:resolved)
      change set_attribute(:resolved_at, &DateTime.utc_now/0)
      change {VehicleIssues.Changes.SanitizeHtml, attributes: [:resolve_comments]}
      change {VehicleIssues.Issue.Changes.NotifyIssueLifecycle, event: :resolved}
    end

    update :close do
      description "Close the issue, optionally noting why."
      require_atomic? false
      accept [:close_comments]

      change transition_state(:closed)
      change set_attribute(:closed_at, &DateTime.utc_now/0)
      change {VehicleIssues.Changes.SanitizeHtml, attributes: [:close_comments]}
      change {VehicleIssues.Issue.Changes.NotifyIssueLifecycle, event: :closed}
    end

    update :reopen do
      description "Reopen a resolved or closed issue, clearing its resolution."
      require_atomic? false

      change transition_state(:open)
      change set_attribute(:resolved_at, nil)
      change set_attribute(:closed_at, nil)
      change set_attribute(:resolve_comments, nil)
      change set_attribute(:close_comments, nil)
    end

    # Bring an archived issue back into the active lists. Non-atomic: writing an audit
    # version (AshPaperTrail full_diff) can't run atomically.
    update :restore do
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end

    # Archives the issue (via AshArchival). Its photos/documents and their stored
    # files are kept, so an issue deleted by mistake can be recovered.
    destroy :destroy do
      primary? true
      require_atomic? false
    end

    # Permanently delete the issue and its stored photo/document files. Excluded
    # from archival (see the archive block), so this really removes everything.
    destroy :purge do
      require_atomic? false

      # The FK cascade removes the photo/document rows, but not their stored bytes.
      # Capture the keys *before* the delete (the cascade wipes the rows during it),
      # then delete the objects from storage after the transaction commits.
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.before_action(fn changeset ->
          issue = Ash.load!(changeset.data, [:photos, :documents], authorize?: false)

          keys =
            Enum.flat_map(issue.photos, &[&1.image_key, &1.thumbnail_key]) ++
              Enum.map(issue.documents, & &1.storage_key)

          Ash.Changeset.set_context(changeset, %{media_keys: keys})
        end)
        |> Ash.Changeset.after_transaction(fn changeset, result ->
          with {:ok, _} <- result do
            Enum.each(Map.get(changeset.context, :media_keys, []), &Fleetms.Storage.delete/1)
          end

          result
        end)
      end
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_issues)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_issue)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_issue)
      # A work order linking/unlinking or resolving its issues on completion.
      authorize_if accessing_from(Fleetms.Maintenance.WorkOrder, :issues)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_issue)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :issue_number, :integer do
      allow_nil? false
      public? true
      writable? false
      description "Per-organization sequential identifier shown as “#42”."
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      public? true
      description "Free-form rich-text details (sanitized HTML from the editor)."
    end

    attribute :priority, VehicleIssues.IssuePriority do
      public? true
      default :Low
      allow_nil? false
    end

    attribute :reported_at, :utc_datetime do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
      description "When the issue was opened."
    end

    attribute :due_date, :date do
      public? true
      description "When the issue should be resolved or closed by."
    end

    attribute :mileage, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
      description "Vehicle mileage snapshot when the issue was reported."
    end

    attribute :hours, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
      description "Vehicle engine hours snapshot when the issue was reported."
    end

    attribute :resolved_at, :utc_datetime, public?: true
    attribute :closed_at, :utc_datetime, public?: true

    attribute :resolve_comments, :string do
      public? true
      constraints max_length: 1000
      description "How the issue was resolved (sanitized HTML)."
    end

    attribute :close_comments, :string do
      public? true
      constraints max_length: 1000
      description "Why the issue was closed (sanitized HTML)."
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :reported_by, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? false
      public? true
      description "The member who opened the issue (the acting user)."
    end

    belongs_to :assigned_to, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
      attribute_writable? true
      description "The member responsible for the issue."
    end

    belongs_to :work_order, Fleetms.Maintenance.WorkOrder do
      domain Fleetms.Maintenance
      allow_nil? true
      public? true
      attribute_writable? true
      description "The work order raised to address this issue, if any."
    end

    has_many :photos, Fleetms.VehicleIssues.IssuePhoto
    has_many :documents, Fleetms.VehicleIssues.IssueDocument
    has_many :issue_watchers, Fleetms.VehicleIssues.IssueWatcher

    many_to_many :tags, Fleetms.Tagging.Tag do
      domain Fleetms.Tagging
      through Fleetms.Tagging.Tagging
      source_attribute_on_join_resource :issue_id
      destination_attribute_on_join_resource :tag_id
    end
  end

  aggregates do
    count :photos_count, :photos
    count :documents_count, :documents
    count :watchers_count, :issue_watchers
  end

  identities do
    # Partial index: the number is unique only among non-archived issues.
    identity :unique_issue_number, [:issue_number] do
      where expr(is_nil(archived_at))
    end
  end
end
