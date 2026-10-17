defmodule Fleetms.FuelManagement.EconomyTest do
  use Fleetms.DataCase, async: true

  import Fleetms.FuelFixtures
  import Fleetms.VehicleFixtures

  alias Fleetms.FuelManagement.Economy

  setup :shared_org

  defp entry(scope, vehicle, odo, qty, cost \\ Money.new(:USD, "50.00")) do
    fuel_entry_fixture(scope, %{
      vehicle_id: vehicle.id,
      odometer: Decimal.new(odo),
      quantity: Decimal.new(qty),
      cost: cost,
      refueled_at: DateTime.add(~U[2026-01-01 08:00:00Z], String.to_integer(odo), :second)
    })
  end

  test "computes fill-to-fill distance and economy, newest first", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    entry(scope, vehicle, "1000", "40")
    entry(scope, vehicle, "1400", "50")
    entry(scope, vehicle, "1800", "45")

    %{rows: [newest, mid, oldest], summary: summary} =
      Economy.for_vehicle(vehicle.id, scope: scope)

    # Oldest entry has no prior odometer to measure against.
    assert oldest.distance == nil
    assert oldest.economy == nil

    assert Decimal.equal?(mid.distance, Decimal.new("400"))
    assert Decimal.equal?(mid.economy, Decimal.new("8.00"))

    assert Decimal.equal?(newest.distance, Decimal.new("400"))
    assert Decimal.equal?(newest.economy, Decimal.new("8.89"))

    assert summary.entry_count == 3
    assert Decimal.equal?(summary.total_volume, Decimal.new("135"))
    assert Decimal.equal?(summary.total_distance, Decimal.new("800"))
    # 800 distance over the 95 units burned across the two measured intervals.
    assert Decimal.equal?(summary.avg_economy, Decimal.new("8.42"))
  end

  test "keeps spend totals per currency", %{scope: scope} do
    vehicle = vehicle_fixture(scope)
    entry(scope, vehicle, "1000", "40", Money.new(:USD, "60.00"))
    entry(scope, vehicle, "1400", "50", Money.new(:USD, "70.00"))
    entry(scope, vehicle, "1800", "45", Money.new(:EUR, "55.00"))

    %{summary: summary} = Economy.for_vehicle(vehicle.id, scope: scope)

    assert [eur, usd] = summary.spend
    assert eur.currency == :EUR
    assert Money.equal?(eur, Money.new(:EUR, "55.00"))
    assert usd.currency == :USD
    assert Money.equal?(usd, Money.new(:USD, "130.00"))
  end

  test "groups monthly volume oldest first", %{scope: scope} do
    vehicle = vehicle_fixture(scope)

    fuel_entry_fixture(scope, %{
      vehicle_id: vehicle.id,
      quantity: Decimal.new("30"),
      refueled_at: ~U[2026-01-10 08:00:00Z]
    })

    fuel_entry_fixture(scope, %{
      vehicle_id: vehicle.id,
      quantity: Decimal.new("20"),
      refueled_at: ~U[2026-02-10 08:00:00Z]
    })

    %{monthly_volume: months} = Economy.for_vehicle(vehicle.id, scope: scope)

    assert [%{label: "Jan 2026"} = jan, %{label: "Feb 2026"}] = months
    assert Decimal.equal?(jan.volume, Decimal.new("30"))
  end

  test "empty vehicle yields a zeroed summary", %{scope: scope} do
    vehicle = vehicle_fixture(scope)

    %{rows: rows, summary: summary, monthly_volume: months} =
      Economy.for_vehicle(vehicle.id, scope: scope)

    assert rows == []
    assert months == []
    assert summary.entry_count == 0
    assert summary.avg_economy == nil
    assert summary.spend == []
  end
end
