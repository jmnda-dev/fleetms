defmodule FleetmsWeb.ExpenseLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures

  alias Fleetms.Expenses
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists expenses", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Grader"})

    Expenses.create_expense!(
      %{
        vehicle_id: vehicle.id,
        expense_date: Date.utc_today(),
        category: :insurance,
        amount: Money.new(:USD, "300.00"),
        description: "Annual cover"
      },
      scope: scope
    )

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/expenses")

    assert html =~ "Expenses"
    assert html =~ "Grader"
    assert html =~ "Insurance"
    assert html =~ "Annual cover"
  end

  test "creates an expense through the form", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Loader"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/expenses/new")

    view
    |> form("#expense-form",
      expense: %{
        vehicle_id: vehicle.id,
        expense_date: Date.to_string(Date.utc_today()),
        category: "toll",
        amount: %{amount: "12.50", currency: "USD"},
        description: "Bridge toll"
      }
    )
    |> render_submit()

    assert [expense] = Expenses.list_expenses!(%{}, scope: scope).results
    assert expense.category == :toll
    assert expense.description == "Bridge toll"
  end

  test "archives an expense", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope)

    expense =
      Expenses.create_expense!(
        %{
          vehicle_id: vehicle.id,
          expense_date: Date.utc_today(),
          category: :parking,
          amount: Money.new(:USD, "5.00")
        },
        scope: scope
      )

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/expenses")
    render_click(view, "archive", %{"id" => expense.id})

    assert Expenses.list_expenses!(%{}, scope: scope).results == []
  end
end
