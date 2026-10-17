defmodule FleetmsWeb.ServiceTaskLiveTest do
  # Not async (ConnCase default): LiveView tests need shared-mode sandbox and a
  # logged-in owner with a real auth token, so they create their own org.
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.MaintenanceFixtures

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  test "lists service tasks and the new action", %{conn: conn, org: org, scope: scope} do
    service_task_fixture(scope, %{name: "Oil & filter change", description: "Every service"})

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/service-tasks")

    assert html =~ "Service Tasks"
    assert html =~ "New service task"
    assert html =~ "Oil &amp; filter change"
  end

  test "searches service tasks by name", %{conn: conn, org: org, scope: scope} do
    service_task_fixture(scope, %{name: "Brake inspection"})
    service_task_fixture(scope, %{name: "Windscreen replacement"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-tasks")

    html = render_change(element(view, "form[phx-change=search]"), %{q: "brake"})

    assert html =~ "Brake inspection"
    refute html =~ "Windscreen replacement"
  end

  test "creates a service task", %{conn: conn, org: org, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-tasks/new")

    view
    |> form("#service-task-form", service_task: %{name: "Tyre rotation", description: "4-wheel"})
    |> render_submit()

    assert [task] = Maintenance.list_service_tasks!(%{search_query: "tyre"}, scope: scope)
    assert task.name == "Tyre rotation"
  end

  test "edits a service task", %{conn: conn, org: org, scope: scope} do
    task = service_task_fixture(scope, %{name: "Coolant flush"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-tasks/#{task.id}/edit")

    view
    |> form("#service-task-form", service_task: %{name: "Coolant system flush"})
    |> render_submit()

    assert Maintenance.get_service_task!(task.id, scope: scope).name == "Coolant system flush"
  end

  test "deletes a service task", %{conn: conn, org: org, scope: scope} do
    task = service_task_fixture(scope, %{name: "Air filter swap"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/service-tasks")

    view
    |> element(~s|button[phx-click="delete"][phx-value-id="#{task.id}"]|)
    |> render_click()

    assert Maintenance.list_service_tasks!(%{}, scope: scope) == []
  end
end
