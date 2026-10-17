defmodule Fleetms.VehicleManagement.VehicleRenewalTest do
  use Fleetms.DataCase, async: true

  import Fleetms.VehicleFixtures

  alias Fleetms.VehicleManagement

  setup :shared_org

  defp days_from_today(n), do: Date.add(Date.utc_today(), n)

  defp status(renewal, scope) do
    VehicleManagement.get_vehicle_renewal!(renewal.id, scope: scope, load: [:status]).status
  end

  describe "create + derived status" do
    test "creates a renewal", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      type = renewal_type_fixture(scope)

      assert {:ok, renewal} =
               VehicleManagement.create_vehicle_renewal(
                 %{
                   vehicle_id: vehicle.id,
                   renewal_type_id: type.id,
                   due_date: days_from_today(100)
                 },
                 scope: scope
               )

      assert renewal.vehicle_id == vehicle.id
    end

    test "status is Upcoming when the due date is far off", %{scope: scope} do
      renewal = vehicle_renewal_fixture(scope, %{due_date: days_from_today(100)})
      assert status(renewal, scope) == "Upcoming"
    end

    test "status is Due Soon inside the notify-before window", %{scope: scope} do
      renewal =
        vehicle_renewal_fixture(scope, %{
          due_date: days_from_today(10),
          notify_before: 30,
          notify_before_unit: :days
        })

      assert status(renewal, scope) == "Due Soon"
    end

    test "status is Overdue once the due date has passed", %{scope: scope} do
      renewal = vehicle_renewal_fixture(scope, %{due_date: days_from_today(-1)})
      assert status(renewal, scope) == "Overdue"
    end

    test "computes notify_from_date with exact month math", %{scope: scope} do
      renewal =
        vehicle_renewal_fixture(scope, %{
          due_date: ~D[2026-03-31],
          notify_before: 1,
          notify_before_unit: :months
        })

      assert renewal.notify_from_date == ~D[2026-02-28]
    end

    test "enforces one renewal per vehicle + type", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      type = renewal_type_fixture(scope)

      vehicle_renewal_fixture(scope, %{vehicle_id: vehicle.id, renewal_type_id: type.id})

      assert {:error, _} =
               VehicleManagement.create_vehicle_renewal(
                 %{
                   vehicle_id: vehicle.id,
                   renewal_type_id: type.id,
                   due_date: days_from_today(10)
                 },
                 scope: scope
               )
    end
  end

  describe "validations" do
    test "rejects an interval amount without a unit", %{scope: scope} do
      vehicle = vehicle_fixture(scope)
      type = renewal_type_fixture(scope)

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.create_vehicle_renewal(
                 %{
                   vehicle_id: vehicle.id,
                   renewal_type_id: type.id,
                   due_date: days_from_today(10),
                   recurrence_interval: 1
                 },
                 scope: scope
               )
    end
  end

  describe "mark_renewed" do
    test "rolls the due date forward by the recurrence and stamps completion", %{scope: scope} do
      renewal =
        vehicle_renewal_fixture(scope, %{
          due_date: ~D[2026-01-15],
          recurrence_interval: 1,
          recurrence_unit: :years
        })

      assert {:ok, renewed} = VehicleManagement.mark_renewal_completed(renewal, scope: scope)
      assert renewed.due_date == ~D[2027-01-15]
      assert renewed.last_completed_date == Date.utc_today()
    end

    test "fails on a renewal with no recurrence", %{scope: scope} do
      renewal = vehicle_renewal_fixture(scope, %{due_date: days_from_today(30)})

      assert {:error, %Ash.Error.Invalid{}} =
               VehicleManagement.mark_renewal_completed(renewal, scope: scope)
    end
  end

  describe "list" do
    test "filters by derived status", %{scope: scope} do
      overdue = vehicle_renewal_fixture(scope, %{due_date: days_from_today(-5)})
      upcoming = vehicle_renewal_fixture(scope, %{due_date: days_from_today(200)})

      assert {:ok, page} =
               VehicleManagement.list_vehicle_renewals(
                 %{filters: %{"statuses" => ["Overdue"]}},
                 scope: scope
               )

      ids = Enum.map(page.results, & &1.id)
      assert overdue.id in ids
      refute upcoming.id in ids
    end
  end
end
