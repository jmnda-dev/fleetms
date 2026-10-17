defmodule Fleetms.Expenses.ExpenseTest do
  @moduledoc "Vehicle expenses: create, list, filter and archive."
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures

  alias Fleetms.Expenses

  setup :shared_org

  defp expense_attrs(vehicle, overrides \\ %{}) do
    Enum.into(overrides, %{
      vehicle_id: vehicle.id,
      expense_date: Date.utc_today(),
      category: :insurance,
      amount: Money.new(:USD, "250.00")
    })
  end

  test "creates and reads back an expense", %{scope: scope} do
    vehicle = vehicle_fixture(scope)

    assert {:ok, expense} = Expenses.create_expense(expense_attrs(vehicle), scope: scope)
    assert expense.category == :insurance
    assert {:ok, _} = Expenses.get_expense(expense.id, scope: scope)
  end

  test "lists and filters by category", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    Expenses.create_expense!(expense_attrs(vehicle, %{category: :insurance}), scope: scope)
    Expenses.create_expense!(expense_attrs(vehicle, %{category: :toll}), scope: scope)

    all = Expenses.list_expenses!(%{}, scope: scope)
    assert length(all.results) == 2

    tolls = Expenses.list_expenses!(%{filters: %{"categories" => ["toll"]}}, scope: scope)
    assert length(tolls.results) == 1
    assert hd(tolls.results).category == :toll
  end

  test "archiving hides it from the active list and it can be restored", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    expense = Expenses.create_expense!(expense_attrs(vehicle), scope: scope)

    :ok = Expenses.delete_expense(expense, scope: scope)
    assert Expenses.list_expenses!(%{}, scope: scope).results == []
    assert length(Expenses.list_archived_expenses!(%{}, scope: scope).results) == 1

    archived = hd(Expenses.list_archived_expenses!(%{}, scope: scope).results)
    {:ok, _} = Expenses.restore_expense(archived, %{}, scope: scope)
    assert length(Expenses.list_expenses!(%{}, scope: scope).results) == 1
  end
end
