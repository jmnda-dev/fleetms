defmodule Fleetms.Maintenance.WorkOrderServiceTaskLaborItem do
  @moduledoc """
  Labour recorded against a service task on a work order.

  One resource covers both kinds of labour, distinguished by `labor_type`:

    * `:technician` — an internal member (`technician`), billed as `hours ×
      hourly_rate`.
    * `:vendor` — outsourced to a `vendor`, billed as a single `flat_cost`.

  Modelling both as one line (rather than two parallel tables) keeps a task's
  labour in a single list while still separating internal cost from outsourced
  spend for reporting. `subtotal` is derived on write — `hours × hourly_rate` for a
  technician, the `flat_cost` for a vendor — and frozen, like part subtotals.

  Managed through its parent work-order service task (`type: :direct_control`).
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Maintenance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Fleetms.Maintenance.WorkOrderServiceTaskLaborItem.Changes.CalculateLaborSubtotal

  postgres do
    table "work_order_service_task_labor_items"
    repo Fleetms.Repo

    references do
      reference :work_order_service_task, on_delete: :delete
      reference :technician, on_delete: :nilify
      reference :vendor, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    create :create do
      primary? true
      accept [:labor_type, :description, :hours, :hourly_rate, :flat_cost]

      argument :technician_id, :uuid
      argument :vendor_id, :uuid

      change manage_relationship(:technician_id, :technician, type: :append_and_remove)
      change manage_relationship(:vendor_id, :vendor, type: :append_and_remove)
      change CalculateLaborSubtotal
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:labor_type, :description, :hours, :hourly_rate, :flat_cost]

      argument :technician_id, :uuid
      argument :vendor_id, :uuid

      change manage_relationship(:technician_id, :technician, type: :append_and_remove)
      change manage_relationship(:vendor_id, :vendor, type: :append_and_remove)
      change CalculateLaborSubtotal
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if accessing_from(Fleetms.Maintenance.WorkOrderServiceTask, :labor_items)
    end
  end

  validations do
    validate present(:technician_id) do
      where attribute_equals(:labor_type, :technician)
      message "is required for technician labour"
    end

    validate present(:vendor_id) do
      where attribute_equals(:labor_type, :vendor)
      message "is required for vendor labour"
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :labor_type, Fleetms.Maintenance.LaborType do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
      constraints max_length: 500
    end

    attribute :hours, :decimal do
      public? true
      constraints min: 0, max: 999_999
      description "Hours worked (technician labour)."
    end

    attribute :hourly_rate, AshMoney.Types.Money do
      public? true
      description "Charge per hour (technician labour)."
    end

    attribute :flat_cost, AshMoney.Types.Money do
      public? true
      description "The vendor's flat charge (vendor labour)."
    end

    attribute :subtotal, AshMoney.Types.Money do
      public? true
      writable? false
      description "Derived labour cost, frozen at write time."
    end

    timestamps()
  end

  relationships do
    belongs_to :work_order_service_task, Fleetms.Maintenance.WorkOrderServiceTask do
      allow_nil? false
    end

    belongs_to :technician, Fleetms.Accounts.User do
      domain Fleetms.Accounts
      allow_nil? true
      public? true
    end

    belongs_to :vendor, Fleetms.Maintenance.Vendor do
      allow_nil? true
      public? true
    end
  end
end
