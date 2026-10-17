defmodule Fleetms.Expenses.Expense do
  @moduledoc """
  A vehicle cost that isn't fuel or a work order — insurance, registration, tolls,
  fines, cleaning, a loan payment, and so on.

  Each expense belongs to a vehicle and carries a `Money` amount in its own
  currency, so it can be attributed to that vehicle's total cost of ownership. A
  vendor can optionally be linked. Soft-deleted (AshArchival) like the other
  operational records, so a mistaken delete is recoverable.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.Expenses,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [Fleetms.Permissions.Dsl, AshArchival.Resource, AshJsonApi.Resource],
    # Owner-scopes expenses for the individuals pool (owner_id + stamp + read filter).
    fragments: [Fleetms.Owned]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.Expenses

  @writable_attrs [
    :expense_date,
    :category,
    :amount,
    :description,
    :odometer,
    :vehicle_id,
    :vendor_id
  ]

  postgres do
    table "expenses"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
      reference :vendor, on_delete: :nilify
    end
  end

  permissions do
    permission :view_expenses, action: :read, label: "View Expenses", group: "Expenses"
    permission :create_expense, action: :create, label: "Create Expense", group: "Expenses"
    permission :update_expense, action: :update, label: "Update Expense", group: "Expenses"
    permission :delete_expense, action: :destroy, label: "Delete Expense", group: "Expenses"
  end

  archive do
    exclude_read_actions([:list_archived])
  end

  json_api do
    type "expense"
  end

  actions do
    defaults [:read, :destroy]
    default_accept []

    read :get_by_id do
      get_by :id
      prepare build(load: [:vehicle, :vendor])
    end

    read :list do
      argument :search_query, :string, default: ""
      argument :filters, :map, default: %{}

      argument :sort_by, :atom do
        default :expense_date
        constraints one_of: [:expense_date, :amount, :category, :inserted_at]
      end

      argument :sort_order, :atom do
        default :desc
        constraints one_of: [:asc, :desc]
      end

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      prepare Expenses.Expense.Preparations.ListExpenses
    end

    read :list_archived do
      argument :search_query, :string, default: ""

      pagination offset?: true, countable: true, default_limit: 20, max_page_size: 100

      filter expr(not is_nil(archived_at))
      prepare Expenses.Expense.Preparations.ListExpenses
    end

    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false
      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(sort: [expense_date: :desc], load: [:vendor])
    end

    create :create do
      primary? true
      accept @writable_attrs

      validate present(:vehicle_id), message: "Pick a vehicle."
    end

    update :update do
      primary? true
      require_atomic? false
      accept @writable_attrs
    end

    update :restore do
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_expenses)
    end

    policy action_type(:create) do
      authorize_if has_permission(:create_expense)
    end

    policy action_type(:update) do
      authorize_if has_permission(:update_expense)
    end

    policy action_type(:destroy) do
      authorize_if has_permission(:delete_expense)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :expense_date, :date do
      allow_nil? false
      public? true
    end

    attribute :category, Expenses.ExpenseCategory do
      allow_nil? false
      public? true
    end

    attribute :amount, AshMoney.Types.Money do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :odometer, :decimal do
      public? true
      constraints min: 0, max: 999_999_999
      description "Odometer at the time of the expense, if relevant."
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
      attribute_writable? true
    end

    belongs_to :vendor, Fleetms.Maintenance.Vendor do
      domain Fleetms.Maintenance
      public? true
      attribute_writable? true
    end
  end
end
