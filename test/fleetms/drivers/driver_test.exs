defmodule Fleetms.Drivers.DriverTest do
  @moduledoc "Drivers: create, search, licence expiry surfaced on the calendar."
  use Fleetms.DataCase, async: true

  alias Fleetms.Calendar
  alias Fleetms.Drivers

  setup :shared_org

  defp driver_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{first_name: "John", last_name: "Banda"})
  end

  test "creates and searches drivers", %{scope: scope} do
    Drivers.create_driver!(driver_attrs(%{last_name: "Banda"}), scope: scope)
    Drivers.create_driver!(driver_attrs(%{first_name: "Mary", last_name: "Phiri"}), scope: scope)

    assert length(Drivers.list_drivers!(%{}, scope: scope).results) == 2

    found = Drivers.list_drivers!(%{search_query: "Phiri"}, scope: scope).results
    assert [%{last_name: "Phiri"}] = found
  end

  test "a licence expiry shows up on the calendar", %{scope: scope} do
    expiry = Date.add(Date.utc_today(), 10)

    Drivers.create_driver!(
      driver_attrs(%{license_number: "DL-9", license_expiry: expiry}),
      scope: scope
    )

    events =
      Calendar.events(scope, Date.add(Date.utc_today(), -1), Date.add(Date.utc_today(), 40))

    license = Enum.find(events, &(&1.type == :license))

    assert license
    assert license.date == expiry
    assert license.title =~ "John Banda"
  end

  test "a driver with no licence expiry contributes no calendar event", %{scope: scope} do
    Drivers.create_driver!(driver_attrs(), scope: scope)

    events =
      Calendar.events(scope, Date.add(Date.utc_today(), -30), Date.add(Date.utc_today(), 30))

    refute Enum.any?(events, &(&1.type == :license))
  end
end
