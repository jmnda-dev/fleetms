# The action variants for an inspection workflow — the *then* half of a workflow's
# when→then. Every module here is an embedded resource and a member of the
# `actions` array-union on `Fleetms.Inspections.Schema.Workflow` (tagged by
# `:type`). They are executed by `Fleetms.Inspections.Workflows` when the
# workflow's trigger fires.
#
# Text fields ending in `_template` support `{...}` placeholders rendered against
# the inspection (see `Workflows.render/2`): `{vehicle}`, `{form}`, `{result}`,
# `{failed_count}`, `{submitter}`, and — for item-scoped triggers — `{item}`.

defmodule Fleetms.Inspections.Schema.OpenIssueAction do
  @moduledoc """
  Opens a `Fleetms.VehicleIssues.Issue` against the inspected vehicle, so a failed
  check turns into trackable maintenance work. The issue is linked back onto the
  inspection's failure rows.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :open_issue,
      constraints: [one_of: [:open_issue]]

    attribute :title_template, :string,
      public?: true,
      allow_nil?: false,
      default: "Inspection failure on {vehicle}",
      constraints: [min_length: 1, max_length: 200]

    attribute :priority, Fleetms.VehicleIssues.IssuePriority,
      public?: true,
      allow_nil?: false,
      default: :Medium

    # Who the new issue is assigned to. `:user` uses `assignee_user_id`;
    # `:submitter` assigns the member who filled the inspection; `:unassigned`
    # leaves it for triage.
    attribute :assign_to, :atom,
      public?: true,
      allow_nil?: false,
      default: :unassigned,
      constraints: [one_of: [:unassigned, :submitter, :user]]

    attribute :assignee_user_id, :uuid, public?: true
  end
end

defmodule Fleetms.Inspections.Schema.NotifyAction do
  @moduledoc """
  Notifies chosen recipients about the inspection — the submitter as an
  acknowledgement, a specific member, everyone holding a role (e.g. all
  supervisors), or the organization's owners. Delivery is in-app (the navbar
  bell), by email, or both.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :notify,
      constraints: [one_of: [:notify]]

    # Who to notify. `:submitter` — the member who filled the inspection; `:user`
    # — a specific member (`recipient_user_id`); `:role` — everyone holding a role
    # (`role_id`); `:owners` — the organization's owner(s).
    attribute :to, :atom,
      public?: true,
      allow_nil?: false,
      default: :user,
      constraints: [one_of: [:submitter, :user, :role, :owners]]

    attribute :recipient_user_id, :uuid, public?: true
    attribute :role_id, :uuid, public?: true

    # How to reach them: the in-app bell, an email, or both.
    attribute :channel, :atom,
      public?: true,
      allow_nil?: false,
      default: :in_app,
      constraints: [one_of: [:in_app, :email, :both]]

    attribute :title_template, :string,
      public?: true,
      allow_nil?: false,
      default: "Inspection needs attention on {vehicle}",
      constraints: [min_length: 1, max_length: 200]

    attribute :body_template, :string,
      public?: true,
      constraints: [max_length: 500]
  end
end
