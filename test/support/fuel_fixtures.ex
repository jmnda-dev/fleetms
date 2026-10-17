defmodule Fleetms.FuelFixtures do
  @moduledoc """
  Test fixtures for the fuel domain. All take a `Fleetms.Scope` so they run with a
  real actor + tenant, exactly as the web layer would.
  """
  import Fleetms.VehicleFixtures

  alias Fleetms.FuelManagement

  def fuel_entry_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        odometer: Decimal.new(System.unique_integer([:positive])),
        refueled_at: DateTime.truncate(DateTime.utc_now(), :second),
        quantity: Decimal.new("40.0"),
        cost: Money.new(:USD, "60.00"),
        fuel_type: :diesel,
        vehicle_id: attrs[:vehicle_id] || vehicle_fixture(scope).id
      })

    FuelManagement.create_fuel_entry!(attrs, scope: scope)
  end
end
