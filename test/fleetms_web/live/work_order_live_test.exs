defmodule FleetmsWeb.WorkOrderLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.MaintenanceFixtures
  import Fleetms.InventoryFixtures
  import Fleetms.IssueFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope
  alias Fleetms.VehicleIssues
  alias Fleetms.VehicleManagement

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists work orders and the new action", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Zephyr Hauler"})
    work_order_fixture(scope, %{vehicle_id: vehicle.id})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/work-orders")

    assert html =~ "Work Orders"
    assert html =~ "New work order"
    assert html =~ "Zephyr Hauler"
    assert html =~ "Open"
  end

  test "filters the list by status", %{conn: conn, org: org, scope: scope} do
    open_v = vehicle_fixture(scope, %{name: "Openvan"})
    done_v = vehicle_fixture(scope, %{name: "Donewagon"})
    open_wo = work_order_fixture(scope, %{vehicle_id: open_v.id})
    done = work_order_fixture(scope, %{vehicle_id: done_v.id})
    Maintenance.complete_work_order!(done, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders")

    # Filtering happens through the filter drawer, which submits "apply-filters"
    # and patches to the filtered URL. Assert on work-order ids (which only
    # appear in listed rows), not vehicle names (those also appear in the
    # drawer's vehicle picker).
    html =
      view
      |> form("#work-order-filters", %{"status" => ["completed"]})
      |> render_submit()

    assert html =~ done.id
    refute html =~ open_wo.id
  end

  test "creates a bare work order", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/new")

    view
    |> form("#work-order-form",
      work_order: %{vehicle_id: vehicle.id, description: "General checkup"}
    )
    |> render_submit()

    assert [wo] = Maintenance.list_work_orders!(%{}, scope: scope).results
    assert wo.description == "General checkup"
    assert wo.status == :open
  end

  test "shows the vehicle's current odometer as help under the mileage field", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("84300")})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/work-orders/new?#{%{vehicle_id: vehicle.id}}")

    assert html =~ "Current odometer: 84,300 km"
  end

  test "saving redirects to the work order's detail page", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/new")

    view
    |> form("#work-order-form", work_order: %{vehicle_id: vehicle.id})
    |> render_submit()

    assert [wo] = Maintenance.list_work_orders!(%{}, scope: scope).results
    assert_redirect(view, ~p"/o/#{org}/work-orders/#{wo.id}")
  end

  test "links an open issue to the work order from the form", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Linkrig"})
    issue = issue_fixture(scope, %{vehicle_id: vehicle.id, title: "Squeaky brakes"})

    # Opening with the vehicle preselected offers that vehicle's open issues.
    {:ok, view, html} = live(conn, ~p"/o/#{org}/work-orders/new?#{%{vehicle_id: vehicle.id}}")

    assert html =~ "Issues addressed"
    assert html =~ "Squeaky brakes"

    view
    |> form("#work-order-form")
    |> render_submit(%{work_order: %{"vehicle_id" => vehicle.id, "issue_ids" => [issue.id]}})

    assert VehicleIssues.get_issue!(issue.id, scope: scope).work_order_id != nil
  end

  test "only the selected vehicle's issues are offered", %{conn: conn, org: org, scope: scope} do
    vehicle_a = vehicle_fixture(scope, %{name: "Rig-A"})
    vehicle_b = vehicle_fixture(scope, %{name: "Rig-B"})
    issue_fixture(scope, %{vehicle_id: vehicle_a.id, title: "A-only fault"})
    issue_fixture(scope, %{vehicle_id: vehicle_b.id, title: "B-only fault"})

    # Preselecting vehicle A offers only A's issue, not B's.
    {:ok, _view, html} = live(conn, ~p"/o/#{org}/work-orders/new?#{%{vehicle_id: vehicle_a.id}}")
    assert html =~ "A-only fault"
    refute html =~ "B-only fault"
  end

  test "with no vehicle selected the issues picker is disabled and empty", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope)
    issue_fixture(scope, %{vehicle_id: vehicle.id, title: "Some fault"})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/work-orders/new")

    # No vehicle chosen yet → the select is disabled and offers no issues.
    assert html =~ "Select a vehicle first"
    assert html =~ ~r/id="work_order_issues"[^>]*disabled/
    refute html =~ "Some fault"
  end

  test "offers the vehicle's due reminders and seeds a task line that shows the reset hint", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
    task = service_task_fixture(scope, %{name: "Oil change"})
    service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})
    # push past next-due so the reminder is overdue
    VehicleManagement.update_vehicle!(vehicle, %{mileage: Decimal.new("20000")}, scope: scope)

    {:ok, view, html} = live(conn, ~p"/o/#{org}/work-orders/new?#{%{vehicle_id: vehicle.id}}")

    # the seed panel offers the due reminder
    assert html =~ "Due on this vehicle"
    assert html =~ "Oil change"
    assert html =~ "Overdue"

    # seeding it adds a task line that shows the reset hint
    seeded =
      view
      |> element(~s|button[phx-click="add-due-task"][phx-value-task="#{task.id}"]|)
      |> render_click()

    assert seeded =~ "Completing resets this vehicle&#39;s due reminder"
  end

  test "adds a service task row to the form", %{conn: conn, org: org, scope: scope} do
    service_task_fixture(scope, %{name: "Brake service"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/new")

    html =
      view
      |> element(~s|button[phx-click="add-task"]|)
      |> render_click()

    assert html =~ "Brake service"
    assert html =~ "Add part"
  end

  test "creates a work order with a nested task, part and labour", %{
    conn: conn,
    owner: owner,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope, %{name: "Oil change"})
    part = part_fixture(scope, %{name: "Oil filter"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders/new")

    params = %{
      "vehicle_id" => vehicle.id,
      "work_order_service_tasks" => %{
        "0" => %{
          "service_task_id" => task.id,
          "work_order_service_task_parts" => %{
            "0" => %{
              "part_id" => part.id,
              "quantity" => "2",
              "unit_cost" => %{"amount" => "12.50", "currency" => "USD"}
            }
          },
          "labor_items" => %{
            "0" => %{
              "labor_type" => "technician",
              "technician_id" => owner.id,
              "hours" => "1.5",
              "hourly_rate" => %{"amount" => "40.00", "currency" => "USD"}
            }
          }
        }
      }
    }

    view
    |> form("#work-order-form")
    |> render_submit(%{work_order: params})

    assert [wo] = Maintenance.list_work_orders!(%{}, scope: scope).results

    wo =
      Maintenance.get_work_order!(wo.id,
        scope: scope,
        load: [work_order_service_tasks: [:work_order_service_task_parts, :labor_items]]
      )

    assert [line] = wo.work_order_service_tasks
    assert [part_line] = line.work_order_service_task_parts
    assert Money.equal?(part_line.subtotal, Money.new(:USD, "25.00"))
    assert [labor] = line.labor_items
    assert Money.equal?(labor.subtotal, Money.new(:USD, "60.00"))
  end

  test "archives a work order, then restores it from the archived view", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Archivan"})
    wo = work_order_fixture(scope, %{vehicle_id: vehicle.id})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/work-orders")

    view
    |> element(~s|button[phx-click="archive"][phx-value-id="#{wo.id}"]|)
    |> render_click()

    refute Enum.any?(Maintenance.list_work_orders!(%{}, scope: scope).results, &(&1.id == wo.id))

    {:ok, archived, html} = live(conn, ~p"/o/#{org}/work-orders?archived=1")
    assert html =~ "Archived work orders"
    assert html =~ "Archivan"

    archived
    |> element(~s|button[phx-click="restore"][phx-value-id="#{wo.id}"]|)
    |> render_click()

    assert Enum.any?(Maintenance.list_work_orders!(%{}, scope: scope).results, &(&1.id == wo.id))
  end

  test "permanently deletes an archived work order", %{conn: conn, org: org, scope: scope} do
    wo = work_order_fixture(scope)
    :ok = Maintenance.delete_work_order(wo, scope: scope)

    {:ok, view, html} = live(conn, ~p"/o/#{org}/work-orders?archived=1")
    assert html =~ "Delete permanently"

    view
    |> element(~s|button[phx-click="purge"][phx-value-id="#{wo.id}"]|)
    |> render_click()

    assert {:error, _} = Maintenance.get_work_order(wo.id, scope: scope)

    refute Enum.any?(
             Maintenance.list_archived_work_orders!(%{}, scope: scope).results,
             &(&1.id == wo.id)
           )
  end
end
