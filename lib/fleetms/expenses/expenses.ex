defmodule Fleetms.Expenses do
  @moduledoc """
  The expenses domain: per-vehicle costs that aren't fuel or a work order
  (insurance, registration, tolls, fines, and so on). These feed a vehicle's
  total cost of ownership alongside fuel and maintenance.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/expenses", Fleetms.Expenses.Expense do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.Expenses.Expense do
      define :list_expenses, action: :list
      define :list_archived_expenses, action: :list_archived
      define :list_vehicle_expenses, action: :list_by_vehicle, args: [:vehicle_id]
      define :get_expense, action: :get_by_id, args: [:id]
      define :create_expense, action: :create
      define :update_expense, action: :update
      define :delete_expense, action: :destroy
      define :restore_expense, action: :restore
    end
  end
end
