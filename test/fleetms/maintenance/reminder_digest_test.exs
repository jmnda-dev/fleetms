defmodule Fleetms.Maintenance.ReminderDigestTest do
  use Fleetms.DataCase, async: true

  import Fleetms.MaintenanceFixtures
  import Fleetms.VehicleFixtures
  import Swoosh.TestAssertions

  alias Fleetms.Maintenance.ReminderDigest
  alias Fleetms.VehicleManagement

  setup :shared_org

  defp tenant(org), do: "org_#{org.id}"

  test "emails the owner a digest of due-soon/overdue reminders", %{
    scope: scope,
    org: org,
    owner: owner
  } do
    vehicle = vehicle_fixture(scope, %{name: "Digestrig", mileage: Decimal.new("10000")})
    task = service_task_fixture(scope, %{name: "Brake service"})
    service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})
    # push the vehicle past next-due so the reminder reads Overdue
    VehicleManagement.update_vehicle!(vehicle, %{mileage: Decimal.new("20000")}, scope: scope)

    assert {:ok, 1} = ReminderDigest.deliver_for_tenant(tenant(org))

    assert_email_sent(fn email ->
      assert {_, to} = hd(email.to)
      assert to == to_string(owner.email)
      assert email.subject =~ "service reminder"
      assert email.html_body =~ "Digestrig"
      assert email.html_body =~ "Brake service"
      assert email.html_body =~ "Overdue"
    end)
  end

  test "sends nothing when nothing is due", %{scope: scope, org: org} do
    vehicle = vehicle_fixture(scope, %{mileage: Decimal.new("10000")})
    task = service_task_fixture(scope)
    # next due 15,000, vehicle at 10,000 → Upcoming, not in the digest
    service_reminder_fixture(scope, vehicle, task, %{mileage_interval: Decimal.new("5000")})

    assert {:ok, 0} = ReminderDigest.deliver_for_tenant(tenant(org))
    assert_no_email_sent()
  end
end
