defmodule Fleetms.Tagging.Tagging do
  @moduledoc """
  Attaches one `Tag` to one record — an issue, work order, vehicle or part. This is the
  polymorphic join: one nullable foreign key per taggable type, with a database check
  constraint enforcing that **exactly one** parent is set (the same shape as comments).
  Real foreign keys give proper cascade behaviour — deleting a record, or the tag,
  removes the attachment.

  A record's tags are managed through that record's own action (`many_to_many :tags`),
  so these rows are almost always written via `manage_relationship`, not directly. A
  partial unique index per parent stops the same tag being attached twice.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Tagging,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "taggings"
    repo Fleetms.Repo

    references do
      reference :tag, on_delete: :delete
      reference :issue, on_delete: :delete
      reference :work_order, on_delete: :delete
      reference :vehicle, on_delete: :delete
      reference :part, on_delete: :delete
    end

    check_constraints do
      check_constraint :tag_id,
        name: "taggings_exactly_one_parent",
        check: "num_nonnulls(issue_id, work_order_id, vehicle_id, part_id) = 1",
        message: "a tag must be attached to exactly one record"
    end

    custom_indexes do
      index [:tag_id, :issue_id], unique: true, where: "issue_id IS NOT NULL"
      index [:tag_id, :work_order_id], unique: true, where: "work_order_id IS NOT NULL"
      index [:tag_id, :vehicle_id], unique: true, where: "vehicle_id IS NOT NULL"
      index [:tag_id, :part_id], unique: true, where: "part_id IS NOT NULL"
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    # Attachments carry no sensitivity of their own — access is really controlled by the
    # parent record's action (the update that manages its tags is permission-gated). Any
    # signed-in member may read/write them; there is no direct UI for them.
    policy always() do
      authorize_if actor_present()
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
    belongs_to :tag, Fleetms.Tagging.Tag do
      allow_nil? false
      public? true
      attribute_writable? true
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

    belongs_to :part, Fleetms.Inventory.Part do
      domain Fleetms.Inventory
      public? true
      attribute_writable? true
    end
  end
end
