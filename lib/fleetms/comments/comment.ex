defmodule Fleetms.Comments.Comment do
  @moduledoc """
  A comment posted by a member on one record — an issue, work order, vehicle or
  inspection. Comments are the shared discussion thread reused across those pages.

  The parent is modelled as one nullable foreign key per commentable type, with a
  database check constraint enforcing that **exactly one** is set. This keeps real
  foreign keys and cascade behaviour (deleting a record removes its comments) while
  letting a single resource serve every page.

  A comment can `@mention` members; the chosen member ids are stored on
  `mentioned_user_ids` (the compose UI records them explicitly, so there's no text
  parsing). On create, `Changes.NotifyParticipants` turns mentions and the parent's
  participants into in-app notifications.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Comments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl]

  import Fleetms.Permissions, only: [has_permission: 1]

  @parent_keys [:issue_id, :work_order_id, :vehicle_id, :inspection_id]

  postgres do
    table "comments"
    repo Fleetms.Repo

    references do
      reference :issue, on_delete: :delete
      reference :work_order, on_delete: :delete
      reference :vehicle, on_delete: :delete
      reference :inspection, on_delete: :delete
      reference :author, on_delete: :nilify
    end

    check_constraints do
      check_constraint :issue_id,
        name: "comments_exactly_one_parent",
        check: "num_nonnulls(issue_id, work_order_id, vehicle_id, inspection_id) = 1",
        message: "a comment must belong to exactly one record"
    end
  end

  permissions do
    permission :view_comments,
      action: :read,
      label: "View Comments",
      group: "Collaboration"

    permission :create_comment,
      action: :create,
      label: "Post Comments",
      group: "Collaboration"

    permission :delete_comments,
      action: :destroy,
      label: "Delete Others' Comments",
      group: "Collaboration"
  end

  actions do
    defaults [:read]
    default_accept []

    # Comments for one parent record, oldest first (a chronological thread). The
    # caller passes exactly one parent id; the others stay nil and don't filter.
    read :list do
      argument :issue_id, :uuid
      argument :work_order_id, :uuid
      argument :vehicle_id, :uuid
      argument :inspection_id, :uuid

      filter expr(
               if(is_nil(^arg(:issue_id)), do: true, else: issue_id == ^arg(:issue_id)) and
                 if(is_nil(^arg(:work_order_id)),
                   do: true,
                   else: work_order_id == ^arg(:work_order_id)
                 ) and
                 if(is_nil(^arg(:vehicle_id)), do: true, else: vehicle_id == ^arg(:vehicle_id)) and
                 if(is_nil(^arg(:inspection_id)),
                   do: true,
                   else: inspection_id == ^arg(:inspection_id)
                 )
             )

      prepare build(
                sort: [inserted_at: :asc],
                load: [author: [:email, profile: [:first_name, :last_name]]]
              )
    end

    create :create do
      primary? true
      accept [:body, :mentioned_user_ids | @parent_keys]

      change relate_actor(:author)
      change Fleetms.Comments.Comment.Changes.NotifyParticipants
    end

    update :update do
      primary? true
      accept [:body, :mentioned_user_ids]
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_comments)
    end

    policy action(:create) do
      authorize_if has_permission(:create_comment)
    end

    # Only the author edits their own comment.
    policy action(:update) do
      authorize_if expr(author_id == ^actor(:id))
    end

    # The author can remove their own comment; moderators need the permission.
    policy action_type(:destroy) do
      authorize_if expr(author_id == ^actor(:id))
      authorize_if has_permission(:delete_comments)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 5000
    end

    attribute :mentioned_user_ids, {:array, :uuid} do
      allow_nil? false
      public? true
      default []
      description "Members explicitly @mentioned in the body, recorded by the compose UI."
    end

    timestamps()
  end

  relationships do
    belongs_to :author, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
      description "The member who wrote the comment; nil if they later left the org."
    end

    belongs_to :issue, Fleetms.VehicleIssues.Issue do
      domain Fleetms.VehicleIssues
      public? true
      attribute_writable? true
    end

    belongs_to :work_order, Fleetms.Maintenance.WorkOrder do
      domain Fleetms.Maintenance
      public? true
      attribute_writable? true
    end

    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      domain Fleetms.VehicleManagement
      public? true
      attribute_writable? true
    end

    belongs_to :inspection, Fleetms.Inspections.Inspection do
      domain Fleetms.Inspections
      public? true
      attribute_writable? true
    end
  end
end
