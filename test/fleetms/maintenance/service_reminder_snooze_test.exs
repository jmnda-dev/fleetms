defmodule Fleetms.Maintenance.ServiceReminderSnoozeTest do
  @moduledoc "Snoozing postpones a reminder's due date (date-based only)."
  use Fleetms.DataCase, async: true

  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.Maintenance

  setup :shared_org

  test "snooze pushes the due date out by the given days", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)

    reminder =
      service_reminder_fixture(scope, vehicle, task, %{
        time_interval: 1,
        time_interval_unit: :month
      })

    assert reminder.next_due_date
    original = reminder.next_due_date

    {:ok, snoozed} = Maintenance.snooze_service_reminder(reminder, 7, scope: scope)

    assert Date.diff(snoozed.next_due_date, original) == 7
  end

  test "snoozing an overdue reminder pushes from today, not the past date", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)

    reminder =
      service_reminder_fixture(scope, vehicle, task, %{
        time_interval: 1,
        time_interval_unit: :month
      })

    # Force the reminder into the past.
    past = Date.add(Date.utc_today(), -30)
    reminder = Ash.Seed.update!(reminder, %{next_due_date: past})

    {:ok, snoozed} = Maintenance.snooze_service_reminder(reminder, 14, scope: scope)

    assert Date.diff(snoozed.next_due_date, Date.utc_today()) == 14
  end

  test "a mileage-only reminder can't be snoozed", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    task = service_task_fixture(scope)

    # Default fixture is mileage-only, so next_due_date is nil.
    reminder = service_reminder_fixture(scope, vehicle, task)
    assert is_nil(reminder.next_due_date)

    assert {:error, _} = Maintenance.snooze_service_reminder(reminder, 7, scope: scope)
  end
end
