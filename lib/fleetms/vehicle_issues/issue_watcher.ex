defmodule Fleetms.VehicleIssues.IssueWatcher do
  @moduledoc """
  A user watching an issue. Watchers are notified when the issue is resolved or
  closed (see `Changes.NotifyIssueLifecycle`), so someone who cares about a fault
  but didn't report it can still follow it.

  One row per (issue, user); watching is idempotent via an upsert on that identity.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleIssues,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1]

  postgres do
    table "issue_watchers"
    repo Fleetms.Repo

    references do
      reference :issue, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    create :watch do
      primary? true
      upsert? true
      upsert_identity :unique_issue_user
      accept [:issue_id, :user_id]
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # Watching is a personal, low-stakes action available to anyone who can see
    # the issue.
    policy action_type([:read, :create, :destroy]) do
      authorize_if has_permission(:view_issues)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :issue, Fleetms.VehicleIssues.Issue do
      allow_nil? false
      public? true
    end

    belongs_to :user, Fleetms.Accounts.User do
      allow_nil? false
      public? true
      domain Fleetms.Accounts
    end
  end

  identities do
    identity :unique_issue_user, [:issue_id, :user_id]
  end
end
