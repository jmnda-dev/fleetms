defmodule Fleetms.VehicleManagement.VehicleAssignment do
  @moduledoc """
  A period during which a vehicle is assigned to a member (driver/operator).

  Carries the start/end datetimes, the odometer readings at hand-over and return,
  and free-form comments. The assignment's `status` (Upcoming / In-progress /
  Past) is **derived from the dates**, not stored — there is no lifecycle to
  manage, so it can never drift. Two safeguards keep the data sane: an
  assignment's end must not precede its start, and a vehicle cannot have two
  assignments whose periods overlap.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshPaperTrail.Resource, AshJsonApi.Resource],
    # Owner-scopes assignments for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.VehicleManagement

  postgres do
    table "vehicle_assignments"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :assignee, on_delete: :nothing
      # Keep the assignment history if a driver is deleted; just unlink it.
      reference :driver, on_delete: :nilify
    end
  end

  permissions do
    permission :view_assignments,
      action: :read,
      label: "View Assignments",
      group: "Assignments"

    permission :create_assignment,
      action: :create,
      label: "Create Assignment",
      group: "Assignments"

    permission :update_assignment,
      action: :update,
      label: "Update Assignment",
      group: "Assignments"

    permission :delete_assignment,
      action: :destroy,
      label: "Delete Assignment",
      group: "Assignments"
  end

  @writable_attrs [
    :start_datetime,
    :end_datetime,
    :start_mileage,
    :end_mileage,
    :comments,
    :vehicle_id,
    :assignee_id,
    :driver_id
  ]

  # Audit trail (AshPaperTrail): each create/update/destroy writes a
  # `vehicle_assignments_versions` row (in the tenant schema) with the acting user, the
  # action name and a full diff — who a vehicle was assigned to, and when it ended.
  paper_trail do
    change_tracking_mode(:full_diff)
    store_action_name?(true)
    reference_source?(false)
    ignore_attributes([:inserted_at, :updated_at])
    belongs_to_actor(:user, Fleetms.Accounts.User, domain: Fleetms.Accounts)
  end

  json_api do
    type "vehicle-assignment"
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
        default :start_datetime
        constraints one_of: [:start_datetime, :end_datetime, :status, :inserted_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare VehicleManagement.VehicleAssignment.Preparations.ListAssignments
    end

    # A vehicle's assignments, most recent first — the "who had this vehicle when" list
    # shown on the vehicle detail page.
    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false
      filter expr(vehicle_id == ^arg(:vehicle_id))

      prepare build(
                sort: [start_datetime: :desc],
                load: [:status, :driver, assignee: [:email, profile: [:first_name, :last_name]]]
              )
    end

    create :create do
      primary? true
      accept @writable_attrs

      # Exactly one responsible party — a member or a driver, never both.
      validate present([:assignee_id, :driver_id], exactly: 1) do
        message "Assign the vehicle to either a member or a driver, not both."
      end

      validate VehicleManagement.VehicleAssignment.Validations.ValidDatetimeRange
      validate VehicleManagement.VehicleAssignment.Validations.NoOverlappingAssignment
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs

      # Exactly one responsible party — a member or a driver, never both.
      validate present([:assignee_id, :driver_id], exactly: 1) do
        message "Assign the vehicle to either a member or a driver, not both."
      end

      validate VehicleManagement.VehicleAssignment.Validations.ValidDatetimeRange
      validate VehicleManagement.VehicleAssignment.Validations.NoOverlappingAssignment
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
      authorize_if has_permission(:view_assignments)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_assignment)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_assignment)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_assignment)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :start_datetime, :utc_datetime do
      allow_nil? false
      public? true
      description "When the vehicle was handed over to the assignee."
    end

    attribute :end_datetime, :utc_datetime do
      public? true
      description "When the vehicle was returned. Open-ended while unset."
    end

    attribute :start_mileage, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
      description "Odometer reading at hand-over."
    end

    attribute :end_mileage, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
      description "Odometer reading at return."
    end

    attribute :comments, :string do
      public? true
      constraints max_length: 500
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    # A vehicle is assigned to a member (a user with a login) OR a driver (a person
    # without one) — at least one, enforced by the create/update validation.
    belongs_to :assignee, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
      attribute_writable? true
      description "The member the vehicle is assigned to."
    end

    belongs_to :driver, Fleetms.Drivers.Driver do
      domain Fleetms.Drivers
      allow_nil? true
      public? true
      attribute_writable? true
      description "The driver the vehicle is assigned to (no app login needed)."
    end
  end

  calculations do
    # Derived from the dates relative to now — no stored state to keep in sync.
    calculate :status,
              :string,
              expr(
                cond do
                  start_datetime > now() -> "Upcoming"
                  is_nil(end_datetime) or now() < end_datetime -> "In-progress"
                  true -> "Past"
                end
              )
  end
end
