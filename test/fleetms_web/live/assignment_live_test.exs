defmodule FleetmsWeb.AssignmentLiveTest do
  use FleetmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fleetms.VehicleFixtures

  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  setup %{conn: conn} do
    {owner, org} = user_with_org_fixture()
    %{conn: log_in_user(conn, owner), org: org, scope: Scope.new(owner, org, true)}
  end

  describe "index" do
    test "lists assignments and shows the create action", %{conn: conn, org: org, scope: scope} do
      vehicle = vehicle_fixture(scope, %{name: "Assigned-#{uniq()}"})
      vehicle_assignment_fixture(scope, %{vehicle_id: vehicle.id, start_datetime: at(-3600)})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/assignments")

      assert html =~ "Assignments"
      assert html =~ "New assignment"
      assert html =~ vehicle.name
      assert html =~ "In-progress"
    end

    test "deletes an assignment", %{conn: conn, org: org, scope: scope} do
      assignment = vehicle_assignment_fixture(scope, %{start_datetime: at(-3600)})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/assignments")
      render_click(view, "delete", %{"id" => assignment.id})

      assert {:error, _} = VehicleManagement.get_vehicle_assignment(assignment.id, scope: scope)
    end
  end

  describe "new" do
    test "renders the form", %{conn: conn, org: org} do
      {:ok, _view, html} = live(conn, ~p"/o/#{org}/assignments/new")

      assert html =~ "New assignment"
      assert html =~ "Start"
      assert html =~ ~s(type="datetime-local")
    end

    test "shows the vehicle's current odometer as help under start mileage", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("45120")})

      {:ok, _view, html} = live(conn, ~p"/o/#{org}/assignments/new?#{%{vehicle_id: vehicle.id}}")

      assert html =~ "Current odometer: 45,120 km"
    end

    test "creates an assignment (datetime-local casts correctly)", %{
      conn: conn,
      org: org,
      scope: scope
    } do
      vehicle = vehicle_fixture(scope)

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/assignments/new")

      view
      |> form("#assignment-form",
        assignment: %{
          vehicle_id: vehicle.id,
          assignee_id: scope.user.id,
          start_datetime: "2026-07-01T09:00",
          comments: "Morning shift"
        }
      )
      |> render_submit()

      assert {:ok, page} =
               VehicleManagement.list_vehicle_assignments(
                 %{filters: %{"vehicle_id" => vehicle.id}},
                 scope: scope
               )

      assert [assignment] = page.results
      assert assignment.comments == "Morning shift"
      assert assignment.start_datetime == ~U[2026-07-01 09:00:00Z]
    end
  end

  describe "edit" do
    test "updates an assignment", %{conn: conn, org: org, scope: scope} do
      assignment = vehicle_assignment_fixture(scope, %{start_datetime: at(-3600)})

      {:ok, view, _html} = live(conn, ~p"/o/#{org}/assignments/#{assignment.id}/edit")

      view
      |> form("#assignment-form", assignment: %{comments: "Reassigned"})
      |> render_submit()

      assert {:ok, updated} =
               VehicleManagement.get_vehicle_assignment(assignment.id, scope: scope)

      assert updated.comments == "Reassigned"
    end
  end

  defp at(offset_seconds) do
    DateTime.utc_now() |> DateTime.add(offset_seconds, :second) |> DateTime.truncate(:second)
  end

  defp uniq, do: System.unique_integer([:positive])
end
