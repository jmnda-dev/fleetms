defmodule Fleetms.VehicleManagement.VehicleAssignmentTest do
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures

  alias Fleetms.VehicleManagement

  setup :shared_org

  defp at(offset_seconds) do
    DateTime.utc_now() |> DateTime.add(offset_seconds, :second) |> DateTime.truncate(:second)
  end

  defp status(assignment, scope) do
    VehicleManagement.get_vehicle_assignment!(assignment.id, scope: scope, load: [:status]).status
  end

  describe "create + derived status" do
    test "creates an assignment and reads it back", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:ok, assignment} =
               VehicleManagement.create_vehicle_assignment(
                 %{vehicle_id: vehicle.id, assignee_id: scope.user.id, start_datetime: at(-60)},
                 scope: scope
               )

      assert assignment.vehicle_id == vehicle.id
      assert assignment.assignee_id == scope.user.id
    end

    test "status is In-progress for a started, open-ended assignment", %{scope: scope} do
      assignment = vehicle_assignment_fixture(scope, %{start_datetime: at(-3600)})
      assert status(assignment, scope) == "In-progress"
    end

    test "status is Upcoming for a future start", %{scope: scope} do
      assignment = vehicle_assignment_fixture(scope, %{start_datetime: at(3600)})
      assert status(assignment, scope) == "Upcoming"
    end

    test "status is Past once ended", %{scope: scope} do
      assignment =
        vehicle_assignment_fixture(scope, %{start_datetime: at(-7200), end_datetime: at(-3600)})

      assert status(assignment, scope) == "Past"
    end

    test "requires a vehicle and either a member or a driver", %{scope: scope} do
      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle_assignment(%{start_datetime: at(0)}, scope: scope)
    end

    test "assigns a vehicle to a driver instead of a member", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      driver = driver_fixture(scope)

      assert {:ok, assignment} =
               VehicleManagement.create_vehicle_assignment(
                 %{vehicle_id: vehicle.id, driver_id: driver.id, start_datetime: at(-60)},
                 scope: scope
               )

      assert assignment.driver_id == driver.id
      assert is_nil(assignment.assignee_id)
    end

    test "rejects an assignment with neither a member nor a driver", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle_assignment(
                 %{vehicle_id: vehicle.id, start_datetime: at(0)},
                 scope: scope
               )
    end

    test "rejects an assignment to both a member and a driver", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      driver = driver_fixture(scope)

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle_assignment(
                 %{
                   vehicle_id: vehicle.id,
                   assignee_id: scope.user.id,
                   driver_id: driver.id,
                   start_datetime: at(-60)
                 },
                 scope: scope
               )
    end
  end

  describe "validations" do
    test "rejects an end before the start", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle_assignment(
                 %{
                   vehicle_id: vehicle.id,
                   assignee_id: scope.user.id,
                   start_datetime: at(0),
                   end_datetime: at(-3600)
                 },
                 scope: scope
               )
    end

    test "rejects an overlapping assignment for the same vehicle", %{scope: scope} do
      vehicle = vehicle_fixture(scope)

      vehicle_assignment_fixture(scope, %{
        vehicle_id: vehicle.id,
        start_datetime: at(-3600),
        end_datetime: at(3600)
      })

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle_assignment(
                 %{vehicle_id: vehicle.id, assignee_id: scope.user.id, start_datetime: at(0)},
                 scope: scope
               )
    end

    test "allows back-to-back assignments (half-open periods)", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      boundary = at(3600)

      vehicle_assignment_fixture(scope, %{
        vehicle_id: vehicle.id,
        start_datetime: at(-3600),
        end_datetime: boundary
      })

      assert {:ok, _} =
               VehicleManagement.create_vehicle_assignment(
                 %{
                   vehicle_id: vehicle.id,
                   assignee_id: scope.user.id,
                   start_datetime: boundary,
                   end_datetime: at(7200)
                 },
                 scope: scope
               )
    end

    test "allows overlapping periods on different vehicles", %{scope: scope} do
      v1 = vehicle_fixture(scope)
      v2 = vehicle_fixture(scope)

      vehicle_assignment_fixture(scope, %{vehicle_id: v1.id, start_datetime: at(-3600)})

      assert {:ok, _} =
               VehicleManagement.create_vehicle_assignment(
                 %{vehicle_id: v2.id, assignee_id: scope.user.id, start_datetime: at(-3600)},
                 scope: scope
               )
    end

    test "updating an assignment doesn't clash with itself", %{scope: scope} do
      assignment = vehicle_assignment_fixture(scope, %{start_datetime: at(-3600)})

      assert {:ok, _} =
               VehicleManagement.update_vehicle_assignment(
                 assignment,
                 %{comments: "Updated"},
                 scope: scope
               )
    end
  end

  describe "list" do
    test "filters by derived status", %{scope: scope} do
      upcoming = vehicle_assignment_fixture(scope, %{start_datetime: at(3600)})

      past_one =
        vehicle_assignment_fixture(scope, %{start_datetime: at(-7200), end_datetime: at(-3600)})

      assert {:ok, page} =
               VehicleManagement.list_vehicle_assignments(
                 %{filters: %{"statuses" => ["Upcoming"]}},
                 scope: scope
               )

      ids = Enum.map(page.results, & &1.id)
      assert upcoming.id in ids
      refute past_one.id in ids
    end
  end
end
