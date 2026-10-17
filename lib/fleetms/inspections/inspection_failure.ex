defmodule Fleetms.Inspections.InspectionFailure do
  @moduledoc """
  A materialized row for one failed item in a submitted inspection.

  Failures are also embedded in the inspection's answers, but they get their own
  rows (with the item's label and value snapshotted) so failure reporting — "every
  failed brake check this month" — and issue-linking are ordinary, fast queries
  rather than jsonb scans. Rows are created through the inspection's `submit`
  action; a workflow's `open_issue` action later stamps `issue_id` onto them via
  `link_issue`.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Inspections,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "inspection_failures"
    repo Fleetms.Repo

    references do
      reference :inspection, on_delete: :delete
      # Keep the failure row if the issue a workflow opened for it is deleted.
      reference :issue, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    create :create do
      primary? true
      accept [:item_id, :item_label, :value_snapshot, :comment]
    end

    # Link this failure to the issue a workflow opened for it. System-run from the
    # workflow engine (actor-less), so kept minimal.
    update :link_issue do
      accept [:issue_id]
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_inspections)
    end

    policy action_type(:create) do
      authorize_if has_permission(:fill_inspections)
    end

    policy action(:link_issue) do
      authorize_if has_permission(:fill_inspections)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :item_id, :string, public?: true, allow_nil?: false
    attribute :item_label, :string, public?: true
    attribute :value_snapshot, :string, public?: true
    attribute :comment, :string, public?: true, constraints: [max_length: 2000]

    timestamps()
  end

  relationships do
    belongs_to :inspection, Fleetms.Inspections.Inspection do
      allow_nil? false
      public? true
    end

    # The maintenance issue a workflow opened for this failure, if any.
    belongs_to :issue, Fleetms.VehicleIssues.Issue do
      domain Fleetms.VehicleIssues
      allow_nil? true
      public? true
      attribute_writable? true
    end
  end
end
