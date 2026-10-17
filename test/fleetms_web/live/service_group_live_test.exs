defmodule FleetmsWeb.ServiceGroupLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists groups and the new action", %{conn: conn, org: org, scope: scope} do
    service_group_fixture(scope, %{name: "Highway Fleet"})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/service-groups")

    assert html =~ "Service Groups"
    assert html =~ "New group"
    assert html =~ "Highway Fleet"
  end

  test "the vehicle picker renders rich options with a subtitle", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    vehicle_fixture(scope, %{
      name: "Zephyr Hauler",
      license_plate: "ABC-123",
      mileage: Decimal.new("84300")
    })

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/service-groups/new")

    assert html =~ ~s(data-rich="true")
    assert html =~ "data-subtitle"
    assert html =~ "ABC-123"
  end

  test "adds a schedule line row to the form", %{conn: conn, org: org, scope: scope} do
    service_task_fixture(scope, %{name: "Brake service"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-groups/new")

    html =
      view
      |> element(~s|button[phx-click="add-schedule"]|)
      |> render_click()

    assert html =~ "Brake service"
    assert html =~ "Every (mi/km)"
  end

  test "creates a group and fans out reminders to its vehicles", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    v1 = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
    v2 = vehicle_fixture(scope, %{mileage: Decimal.new("20000")})
    task = service_task_fixture(scope)

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-groups/new")

    view
    |> form("#service-group-form")
    |> render_submit(%{
      service_group: %{
        "name" => "Fleet A",
        "vehicle_ids" => [v1.id, v2.id],
        "schedules" => %{
          "0" => %{"service_task_id" => task.id, "mileage_interval" => "5000"}
        }
      }
    })

    assert [group] = Maintenance.list_service_groups!(%{}, scope: scope)
    assert group.name == "Fleet A"

    reminders = Maintenance.list_service_reminders!(%{}, scope: scope).results
    assert length(reminders) == 2
  end

  test "deletes a group", %{conn: conn, org: org, scope: scope} do
    group = service_group_fixture(scope, %{name: "Old Fleet"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-groups")

    view
    |> element(~s|button[phx-click="delete"][phx-value-id="#{group.id}"]|)
    |> render_click()

    assert Maintenance.list_service_groups!(%{}, scope: scope) == []
  end
end
