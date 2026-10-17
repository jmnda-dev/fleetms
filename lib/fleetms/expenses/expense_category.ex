defmodule Fleetms.Expenses.ExpenseCategory do
  @moduledoc "The kinds of vehicle expense that aren't fuel or a work order."
  use Ash.Type.Enum,
    values: [
      :insurance,
      :registration,
      :tax,
      :toll,
      :parking,
      :fine,
      :cleaning,
      :storage,
      :loan_or_lease,
      :other
    ]
end
