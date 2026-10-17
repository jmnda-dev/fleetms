defmodule FleetmsWeb.InspectionScheduleLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures

  alias Fleetms.Inspections
  alias Fleetms.Inspections.{InspectionSchedule, ScheduleRunner}
  alias Fleetms.Scope

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), owner: owner, org: org, scope: Scope.new(owner, org, true)}
  end

  defp published_form(scope) do
    schema = %{
      "sections" => [
        %{
          "id" => "s1",
          "title" => "Checks",
          "items" => [
            %{"id" => "brakes", "label" => "Brakes", "config" => %{"type" => "pass_fail"}}
          ]
        }
      ]
    }

    %{title: "DVIR #{System.unique_integer([:positive])}"}
    |> Inspections.create_inspection_form!(scope: scope)
    |> Inspections.update_inspection_form!(%{draft_schema: schema}, scope: scope)
    |> Inspections.publish_inspection_form!(scope: scope)
  end

  test "lists schedules and the new action", %{conn: conn, org: org, scope: scope} do
    form = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Rig One"})

    Inspections.create_inspection_schedule!(
      %{inspection_form_id: form.id, vehicle_id: vehicle.id, interval_days: 7},
      scope: scope
    )

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/inspection-schedules")

    assert html =~ "Inspection Schedules"
    assert html =~ "New schedule"
    assert html =~ "Rig One"
    assert html =~ "Weekly"
  end

  test "creating a schedule adds it and redirects to the list", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    form = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Rig Two"})

    {:ok, view, _html} = live(conn, ~p"/o/#{org}/inspection-schedules/new")

    view
    |> form("#inspection-schedule-form",
      schedule: %{
        inspection_form_id: form.id,
        vehicle_id: vehicle.id,
        interval_days: 7,
        start_date: Date.to_iso8601(Date.utc_today()),
        active: true
      }
    )
    |> render_submit()

    assert [schedule] = Inspections.list_inspection_schedules!(%{}, scope: scope).results
    assert schedule.interval_days == 7
    assert schedule.vehicle_id == vehicle.id
    assert_redirect(view, ~p"/o/#{org}/inspection-schedules")
  end

  test "the due inspections list shows generated assignments", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    form = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Rig Three"})

    Inspections.create_inspection_schedule!(
      %{inspection_form_id: form.id, vehicle_id: vehicle.id, interval_days: 1},
      scope: scope
    )

    ScheduleRunner.generate_for_tenant(Ash.ToTenant.to_tenant(org, InspectionSchedule))

    {:ok, _view, html} = live(conn, ~p"/o/#{org}/inspection-assignments")

    assert html =~ "Due Inspections"
    assert html =~ "Rig Three"
    assert html =~ form.title
    assert html =~ "Fill"
  end

  test "filling from an assignment's link preselects the form and closes the assignment", %{
    conn: conn,
    org: org,
    scope: scope
  } do
    form = published_form(scope)
    vehicle = vehicle_fixture(scope, %{name: "Rig Four"})

    Inspections.create_inspection_schedule!(
      %{inspection_form_id: form.id, vehicle_id: vehicle.id, interval_days: 1},
      scope: scope
    )

    ScheduleRunner.generate_for_tenant(Ash.ToTenant.to_tenant(org, InspectionSchedule))
    assert [assignment] = Inspections.list_inspection_assignments!(%{}, scope: scope).results

    # The assignment's "Fill" link lands here with the form + vehicle preselected,
    # so the form's items render immediately.
    {:ok, view, html} =
      live(conn, ~p"/o/#{org}/inspections/new?#{%{form_id: form.id, vehicle_id: vehicle.id}}")

    assert html =~ "Brakes"

    view
    |> form("#inspection-fill-form", answers: %{"brakes" => %{"value" => "pass"}})
    |> render_submit()

    completed = Inspections.get_inspection_assignment!(assignment.id, scope: scope)
    assert completed.status == :done
    assert completed.inspection_id
  end
end
