defmodule Fleetms.Maintenance.ServiceReminderTest do
  use Fleetms.DataCase

  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance
  alias Fleetms.VehicleManagement

  setup :shared_org

  defp reminder(scope, mileage, attrs) do
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new(mileage)})
    task = service_task_fixture(scope)
    service_reminder_fixture(scope, vehicle, task, attrs)
  end

  defp status(scope, reminder) do
    Maintenance.get_service_reminder!(reminder.id, scope: scope).due_status
  end

  describe "create" do
    test "baselines from the vehicle's mileage and derives the next-due point", %{scope: scope} do
      r = reminder(scope, "10000", %{mileage_interval: Decimal.new("5000")})

      assert Decimal.equal?(r.last_completed_mileage, Decimal.new("10000"))
      assert Decimal.equal?(r.next_due_mileage, Decimal.new("15000"))
      assert r.last_completed_date == Date.utc_today()
    end

    test "derives next_due_date from the time interval", %{scope: scope} do
      r =
        reminder(scope, "0", %{
          mileage_interval: nil,
          time_interval: 3,
          time_interval_unit: :month
        })

      assert r.next_due_date == Date.shift(Date.utc_today(), month: 3)
    end

    test "rejects a reminder with no interval at all", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      task = service_task_fixture(scope)

      assert_raise Ash.Error.Invalid, fn ->
        Maintenance.create_service_reminder!(
          %{vehicle_id: vehicle.id, service_task_id: task.id},
          scope: scope
        )
      end
    end

    test "rejects a time interval without a unit", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      task = service_task_fixture(scope)

      assert_raise Ash.Error.Invalid, fn ->
        Maintenance.create_service_reminder!(
          %{vehicle_id: vehicle.id, service_task_id: task.id, time_interval: 6},
          scope: scope
        )
      end
    end
  end

  describe "derived due_status" do
    test "upcoming when well before the next-due mileage", %{scope: scope} do
      r = reminder(scope, "10000", %{mileage_interval: Decimal.new("5000")})
      assert status(scope, r) == :upcoming
    end

    test "due_soon when inside the mileage threshold", %{scope: scope} do
      r =
        reminder(scope, "10000", %{
          mileage_interval: Decimal.new("5000"),
          mileage_threshold: Decimal.new("5000")
        })

      assert status(scope, r) == :due_soon
    end

    test "overdue once the vehicle passes the next-due mileage", %{scope: scope} do
      vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      task = service_task_fixture(scope)
      r = service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

      VehicleManagement.update_vehicle!(vehicle, %{mileage: Decimal.new("16000")}, scope: scope)

      assert status(scope, r) == :overdue
    end

    test "due_soon by time when within the day threshold", %{scope: scope} do
      r =
        reminder(scope, "0", %{
          mileage_interval: nil,
          time_interval: 10,
          time_interval_unit: :day,
          time_threshold_days: 10
        })

      assert status(scope, r) == :due_soon
    end
  end

  describe "reset" do
    test "re-baselines to the vehicle's current mileage and clears the overdue state", %{
      scope: scope
    } do
      vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
      task = service_task_fixture(scope)
      r = service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

      VehicleManagement.update_vehicle!(vehicle, %{mileage: Decimal.new("16000")}, scope: scope)
      assert status(scope, r) == :overdue

      r = Maintenance.reset_service_reminder!(r, scope: scope)

      assert Decimal.equal?(r.last_completed_mileage, Decimal.new("16000"))
      assert Decimal.equal?(r.next_due_mileage, Decimal.new("21000"))
      assert status(scope, r) == :upcoming
    end
  end

  describe "list" do
    test "filters by the live due_status", %{scope: scope} do
      upcoming_v = vehicle_fixture(scope, %{name: "Freshvan", mileage: Decimal.new("10000")})
      overdue_v = vehicle_fixture(scope, %{name: "Latewagon", mileage: Decimal.new("10000")})
      task = service_task_fixture(scope)

      service_reminder_fixture(scope, upcoming_v, task, %{mileage_interval: Decimal.new("5000")})
      service_reminder_fixture(scope, overdue_v, task, %{mileage_interval: Decimal.new("5000")})
      VehicleManagement.update_vehicle!(overdue_v, %{mileage: Decimal.new("20000")}, scope: scope)

      page =
        Maintenance.list_service_reminders!(%{filters: %{"due_status" => "overdue"}},
          scope: scope
        )

      assert Enum.map(page.results, & &1.vehicle_name) == ["Latewagon"]
    end
  end
end
