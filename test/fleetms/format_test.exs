defmodule Fleetms.FormatTest do
  use ExUnit.Case, async: true

  alias Fleetms.Format

  defp org(overrides \\ %{}) do
    Enum.into(overrides, %{
      unit_system: :metric,
      currency: "ZMW",
      timezone: "Etc/UTC",
      date_format: :iso
    })
  end

  describe "distance (stored in km)" do
    test "metric shows km with grouping" do
      assert Format.distance(Decimal.new("12000"), org()) == "12,000 km"
    end

    test "imperial converts to miles" do
      assert Format.distance(Decimal.new("12000"), org(%{unit_system: :imperial})) == "7,456.5 mi"
    end

    test "nil renders a dash" do
      assert Format.distance(nil, org()) == "—"
    end

    test "unit label follows the system" do
      assert Format.distance_unit(org()) == "km"
      assert Format.distance_unit(org(%{unit_system: :imperial})) == "mi"
    end
  end

  describe "parsing distance input back to km" do
    test "metric input is stored as entered" do
      assert Decimal.equal?(Format.to_canonical_distance("12000", org()), Decimal.new("12000"))
    end

    test "imperial input is converted to km" do
      # 100 mi × 1.609344 = 160.9344 → 160.93 km (2 dp, to round-trip cleanly)
      result = Format.to_canonical_distance("100", org(%{unit_system: :imperial}))
      assert Decimal.equal?(result, Decimal.new("160.93"))
    end
  end

  describe "rendering a stored value into a unit input" do
    test "metric shows the stored km plainly, no grouping or suffix" do
      assert Format.distance_input(Decimal.new("12000.00"), org()) == "12000"
      assert Format.volume_input(Decimal.new("50"), org()) == "50"
    end

    test "imperial converts km/litres into the display unit" do
      # 12000 km × 0.621371 = 7456.45; 50 L × 0.264172 = 13.21
      assert Format.distance_input(Decimal.new("12000"), org(%{unit_system: :imperial})) ==
               "7456.45"

      assert Format.volume_input(Decimal.new("50"), org(%{unit_system: :imperial})) == "13.21"
    end

    test "nil renders blank" do
      assert Format.distance_input(nil, org()) == ""
    end

    test "a string the user is mid-typing is passed straight through" do
      imperial = org(%{unit_system: :imperial})
      assert Format.distance_input("75.", imperial) == "75."
      assert Format.volume_input("13.", imperial) == "13."
    end
  end

  describe "converting form params to canonical storage" do
    @fields %{"odometer" => :distance, "quantity" => :volume}

    test "metric leaves the numbers as entered" do
      params = %{"odometer" => "12000", "quantity" => "50", "note" => "keep me"}
      result = Format.to_canonical_params(params, @fields, org())
      assert result == %{"odometer" => "12000", "quantity" => "50", "note" => "keep me"}
    end

    test "imperial converts each unit field to canonical" do
      params = %{"odometer" => "100", "quantity" => "10"}
      result = Format.to_canonical_params(params, @fields, org(%{unit_system: :imperial}))
      # 100 mi → 160.93 km, 10 gal → 37.85 L
      assert result == %{"odometer" => "160.93", "quantity" => "37.85"}
    end

    test "blank or missing fields are left untouched" do
      params = %{"odometer" => ""}
      result = Format.to_canonical_params(params, @fields, org(%{unit_system: :imperial}))
      assert result == %{"odometer" => ""}
    end
  end

  describe "volume (stored in litres)" do
    test "metric shows litres, imperial gallons" do
      assert Format.volume(Decimal.new("50"), org()) == "50 L"
      assert Format.volume(Decimal.new("50"), org(%{unit_system: :imperial})) == "13.2 gal"
    end
  end

  describe "dates" do
    test "renders per the org's date format" do
      date = ~D[2026-08-14]
      assert Format.date(date, org(%{date_format: :iso})) == "2026-08-14"
      assert Format.date(date, org(%{date_format: :us})) == "08/14/2026"
      assert Format.date(date, org(%{date_format: :eu})) == "14/08/2026"
      assert Format.date(date, org(%{date_format: :long})) == "August 14, 2026"
    end
  end

  describe "datetimes" do
    test "shifts UTC into the org timezone before formatting" do
      dt = ~U[2026-08-14 22:30:00Z]
      # Lusaka is UTC+2, so 22:30 UTC → 00:30 the next day.
      assert Format.datetime(dt, org(%{timezone: "Africa/Lusaka"})) == "2026-08-15 00:30"
    end

    test "unknown timezone falls back to UTC" do
      dt = ~U[2026-08-14 22:30:00Z]
      assert Format.datetime(dt, org(%{timezone: "Not/AZone"})) == "2026-08-14 22:30"
    end
  end

  describe "numbers and money" do
    test "groups numbers" do
      assert Format.number(Decimal.new("12000")) == "12,000"
      assert Format.number(1_234_567.5) == "1,234,567.5"
      assert Format.number(nil) == "—"
    end

    test "formats money and exposes the default currency" do
      assert Format.money(Money.new("ZMW", "100")) =~ "100"
      assert Format.default_currency(org()) == "ZMW"
    end
  end
end
