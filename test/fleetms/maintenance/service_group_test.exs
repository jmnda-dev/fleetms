defmodule Fleetms.Maintenance.ServiceGroupTest do
  use Fleetms.DataCase

  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance

  setup :shared_org

  defp reminders(scope) do
    Maintenance.list_service_reminders!(%{}, scope: scope).results
  end

  defp reminder_for(scope, vehicle_id) do
    Enum.find(reminders(scope), &(&1.vehicle_id == vehicle_id))
  end

  describe "reminder fan-out" do
    test "creating a group generates a reminder per (schedule × vehicle), baselined per vehicle",
         %{scope: scope} do
      v1 = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      v2 = vehicle_fixture(scope, %{mileage: Decimal.new("20000")})
      task = service_task_fixture(scope)

      service_group_fixture(scope, %{
        name: "Fleet A",
        vehicle_ids: [v1.id, v2.id],
        schedules: [%{service_task_id: task.id, mileage_interval: Decimal.new("5000")}]
      })

      assert length(reminders(scope)) == 2
      # each reminder is baselined from its own vehicle's mileage
      assert Decimal.equal?(reminder_for(scope, v1.id).next_due_mileage, Decimal.new("15000"))
      assert Decimal.equal?(reminder_for(scope, v2.id).next_due_mileage, Decimal.new("25000"))
    end

    test "adding and removing member vehicles adds/removes their reminders", %{scope: scope} do
      v1 = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      v2 = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      v3 = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      task = service_task_fixture(scope)

      group =
        service_group_fixture(scope, %{
          vehicle_ids: [v1.id, v2.id],
          schedules: [%{service_task_id: task.id, mileage_interval: Decimal.new("5000")}]
        })

      group = Maintenance.get_service_group!(group.id, scope: scope)
      [schedule] = group.schedules

      # swap membership: drop v2, add v3 (keep the same schedule line by id)
      Maintenance.update_service_group!(
        group,
        %{
          vehicle_ids: [v1.id, v3.id],
          schedules: [
            %{
              id: schedule.id,
              service_task_id: task.id,
              mileage_interval: Decimal.new("5000")
            }
          ]
        },
        scope: scope
      )

      vehicle_ids = reminders(scope) |> Enum.map(& &1.vehicle_id) |> Enum.sort()
      assert vehicle_ids == Enum.sort([v1.id, v3.id])
    end

    test "editing a schedule's interval updates every member's reminder", %{scope: scope} do
      v1 = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      task = service_task_fixture(scope)

      group =
        service_group_fixture(scope, %{
          vehicle_ids: [v1.id],
          schedules: [%{service_task_id: task.id, mileage_interval: Decimal.new("5000")}]
        })

      group = Maintenance.get_service_group!(group.id, scope: scope)
      [schedule] = group.schedules

      Maintenance.update_service_group!(
        group,
        %{
          vehicle_ids: [v1.id],
          schedules: [
            %{
              id: schedule.id,
              service_task_id: task.id,
              mileage_interval: Decimal.new("10000")
            }
          ]
        },
        scope: scope
      )

      # baseline stayed at 10,000; next due recomputed from the new 10,000 interval
      assert Decimal.equal?(reminder_for(scope, v1.id).next_due_mileage, Decimal.new("20000"))
    end

    test "removing a schedule line deletes the reminders it generated", %{scope: scope} do
      v1 = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      task = service_task_fixture(scope)

      group =
        service_group_fixture(scope, %{
          vehicle_ids: [v1.id],
          schedules: [%{service_task_id: task.id, mileage_interval: Decimal.new("5000")}]
        })

      assert length(reminders(scope)) == 1

      group = Maintenance.get_service_group!(group.id, scope: scope)

      Maintenance.update_service_group!(group, %{vehicle_ids: [v1.id], schedules: []},
        scope: scope
      )

      assert reminders(scope) == []
    end
  end
end
