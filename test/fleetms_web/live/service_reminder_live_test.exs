defmodule FleetmsWeb.ServiceReminderLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists reminders and the new action", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Zephyr Hauler", mileage: Decimal.new("10000")})
    task = service_task_fixture(scope, %{name: "Oil change"})
    service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/service-reminders")

    assert html =~ "Service Reminders"
    assert html =~ "New reminder"
    assert html =~ "Zephyr Hauler"
    assert html =~ "Oil change"
    assert html =~ "Upcoming"
  end

  test "offers a create-work-order shortcut for the reminder's vehicle", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Hauler", mileage: Decimal.new("10000")})
    task = service_task_fixture(scope, %{name: "Oil change"})
    service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/service-reminders")

    assert html =~ "Work order"
    assert html =~ "/work-orders/new?"
    assert html =~ "vehicle_id=#{vehicle.id}"
  end

  test "filters by live due status", %{conn: conn, org: org, scope: scope} do
    task = service_task_fixture(scope)
    fresh = vehicle_fixture(scope, %{name: "Freshvan", mileage: Decimal.new("10000")})
    late = vehicle_fixture(scope, %{name: "Latewagon", mileage: Decimal.new("10000")})
    service_reminder_fixture(scope, fresh, task, %{mileage_interval: Decimal.new("5000")})
    service_reminder_fixture(scope, late, task, %{mileage_interval: Decimal.new("5000")})
    VehicleManagement.update_vehicle!(late, %{mileage: Decimal.new("20000")}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-reminders")

    html = render_change(element(view, "form[phx-change=filter]"), %{status: "overdue"})

    assert html =~ "Latewagon"
    refute html =~ "Freshvan"
  end

  test "creates a reminder", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("8000")})
    task = service_task_fixture(scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-reminders/new")

    view
    |> form("#service-reminder-form")
    |> render_submit(%{
      service_reminder: %{
        "vehicle_id" => vehicle.id,
        "service_task_id" => task.id,
        "mileage_interval" => "5000"
      }
    })

    assert [r] = Maintenance.list_service_reminders!(%{}, scope: scope).results
    assert Decimal.equal?(r.next_due_mileage, Decimal.new("13000"))
  end

  test "resets a reminder from the list", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
    task = service_task_fixture(scope)
    r = service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})
    VehicleManagement.update_vehicle!(vehicle, %{mileage: Decimal.new("16000")}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-reminders")

    view
    |> element(~s|button[phx-click="reset"][phx-value-id="#{r.id}"]|)
    |> render_click()

    r = Maintenance.get_service_reminder!(r.id, scope: scope)
    assert Decimal.equal?(r.last_completed_mileage, Decimal.new("16000"))
    assert r.due_status == :upcoming
  end

  test "archives a reminder, then restores it from the archived view", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle = vehicle_fixture(scope, %{name: "Reminder Rig"})
    task = service_task_fixture(scope, %{name: "Coolant flush"})
    r = service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-reminders")

    view
    |> element(~s|button[phx-click="archive"][phx-value-id="#{r.id}"]|)
    |> render_click()

    assert Maintenance.list_service_reminders!(%{}, scope: scope).results == []

    {:ok, archived, html} = live(conn, ~p"/o/#{org}/service-reminders?archived=1")
    assert html =~ "Archived reminders"
    assert html =~ "Reminder Rig"

    archived
    |> element(~s|button[phx-click="restore"][phx-value-id="#{r.id}"]|)
    |> render_click()

    assert Enum.any?(
             Maintenance.list_service_reminders!(%{}, scope: scope).results,
             &(&1.id == r.id)
           )
  end

  test "shows a vehicle's reminders on its detail page tab", %{conn: conn, org: org, scope: scope} do
    vehicle = vehicle_fixture(scope, %{name: "Tabby Truck", mileage: Decimal.new("10000")})
    task = service_task_fixture(scope, %{name: "Tyre rotation"})
    service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/vehicles/#{vehicle.id}")

    html = render_click(element(view, ~s|[phx-click][phx-value-tab="reminders"]|))

    assert html =~ "Tyre rotation"
    assert html =~ "Upcoming"
  end
end
