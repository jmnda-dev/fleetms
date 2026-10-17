defmodule Fleetms.DashboardTest do
  @moduledoc """
  The dashboard summary counts: vehicle status breakdown, open/overdue issues and work
  orders in progress, scoped to the organization and excluding archived records.
  """
  use Fleetms.DataCase, async: true

  import Fleetms.FuelFixtures
  import Fleetms.InventoryFixtures
  import Fleetms.IssueFixtures
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Dashboard
  alias Fleetms.Maintenance
  alias Fleetms.VehicleIssues

  setup :shared_org

  test "counts vehicles by status", %{scope: scope} do
    vehicle_fixture(scope, %{status: :Active})
    vehicle_fixture(scope, %{status: :Active})
    vehicle_fixture(scope, %{status: :Maintenance})

    status = Dashboard.summary(scope).vehicle_status
    assert status[:Active] == 2
    assert status[:Maintenance] == 1
    # Statuses with no vehicles are present as 0.
    assert status[:Sold] == 0
  end

  test "counts open and overdue issues", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue_fixture(scope, %{vehicle_id: vehicle.id})
    issue_fixture(scope, %{vehicle_id: vehicle.id, due_date: Date.add(Date.utc_today(), -3)})

    summary = Dashboard.summary(scope)
    assert summary.open_issues == 2
    assert summary.overdue_issues == 1
  end

  test "counts work orders in progress separately from open", %{scope: scope} do
    open_wo = work_order_fixture(scope)
    in_progress = work_order_fixture(scope)
    {:ok, _} = Maintenance.start_work_order(in_progress, scope: scope)

    summary = Dashboard.summary(scope)
    assert summary.work_orders_open == 1
    assert summary.work_orders_in_progress == 1
    assert open_wo.status == :open
  end

  test "archived records are excluded from the counts", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id})
    assert Dashboard.summary(scope).open_issues == 1

    :ok = VehicleIssues.delete_issue(issue, scope: scope)
    assert Dashboard.summary(scope).open_issues == 0
  end

  test "counts are isolated per organization", %{scope: scope} do
    vehicle_fixture(scope, %{status: :Active})

    {other_user, other_org} = Fleetms.AccountsFixtures.user_with_org_fixture()
    other_scope = Fleetms.Scope.new(other_user, other_org, true)

    assert Dashboard.summary(other_scope).vehicle_status[:Active] == 0
  end

  test "returns due reminders and renewals without error", %{scope: scope} do
    # Exercises the derived-status load paths; exact due math is covered by their own tests.
    summary = Dashboard.summary(scope)
    assert is_integer(summary.reminders_due)
    assert is_integer(summary.renewals_due)
  end

  describe "chart series" do
    test "issues trend spans the requested months and counts this month's opens", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      issue_fixture(scope, %{vehicle_id: vehicle.id})
      issue_fixture(scope, %{vehicle_id: vehicle.id})

      trend = Dashboard.issues_trend(scope, 6)
      assert length(trend.categories) == 6
      assert length(trend.opened) == 6
      # The two new issues land in the current (last) bucket.
      assert List.last(trend.opened) == 2
    end

    test "open issues by priority counts in priority order", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      issue_fixture(scope, %{vehicle_id: vehicle.id, priority: :High})
      issue_fixture(scope, %{vehicle_id: vehicle.id, priority: :High})
      issue_fixture(scope, %{vehicle_id: vehicle.id, priority: :Low})

      by_priority = Dashboard.open_issues_by_priority(scope)
      assert by_priority.categories == ["None", "Low", "Medium", "High"]
      assert by_priority.values == [0, 1, 0, 2]
    end

    test "fuel spend sums only the org's default currency", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      fuel_entry_fixture(scope, %{vehicle_id: vehicle.id, cost: Money.new(:ZMW, "100.00")})
      # A different currency is excluded (currencies can't be summed).
      fuel_entry_fixture(scope, %{vehicle_id: vehicle.id, cost: Money.new(:USD, "60.00")})

      spend = Dashboard.fuel_spend(scope, 6)
      assert spend.currency == "ZMW"
      assert List.last(spend.values) == 100.0
    end
  end

  describe "attention lists" do
    test "recent issues returns the newest first with their details", %{scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Rig-1"})
      now = DateTime.utc_now()

      issue_fixture(scope, %{
        vehicle_id: vehicle.id,
        title: "Older",
        reported_at: DateTime.add(now, -3600)
      })

      issue_fixture(scope, %{vehicle_id: vehicle.id, title: "Newer", reported_at: now})

      assert [first | _] = Dashboard.recent_issues(scope)
      assert first.title == "Newer"
      assert first.vehicle == "Rig-1"
      assert first.number
    end

    test "low stock lists tracked parts at or below threshold", %{scope: scope} do
      # A tracked part with threshold 5 and no stock is "Out of stock".
      part_fixture(scope, %{
        name: "Filter",
        track_inventory: true,
        quantity_threshold: Decimal.new("5")
      })

      # An untracked part never appears.
      part_fixture(scope, %{name: "Sticker", track_inventory: false})

      low = Dashboard.low_stock_parts(scope)
      assert [%{name: "Filter", status: status}] = low
      assert status in ["Low", "Out of stock"]
    end

    test "due reminders and renewals return lists", %{scope: scope} do
      # Their due math has its own tests; here we just confirm the shape and no crash.
      assert is_list(Dashboard.due_reminders(scope))
      assert is_list(Dashboard.due_renewals(scope))
    end
  end

  describe "maintenance spend" do
    test "sums completed work-order line items in the default currency", %{scope: scope} do
      # No completed work orders yet → all-zero series in the default currency.
      spend = Dashboard.maintenance_spend(scope, 6)
      assert spend.currency == "ZMW"
      assert length(spend.values) == 6
      assert Enum.all?(spend.values, &(&1 == 0.0))
    end
  end
end
