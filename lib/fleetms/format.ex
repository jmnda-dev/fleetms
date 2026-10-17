defmodule Fleetms.Format do
  @moduledoc """
  Formats values for display according to an organization's settings (unit system,
  timezone, date format), and converts unit-bearing input back to canonical storage.

  Distances are stored in kilometres and volumes in litres; datetimes are stored in
  UTC. These helpers convert to the org's chosen units and timezone only at the edges —
  the database always holds canonical values. Numbers are grouped via `Localize`, dates
  via the org's explicit format, and money via `ex_money`.

  Every function takes the organization (usually `scope.organization`) so the same value
  renders differently per org.
  """

  # Canonical (metric) → imperial multipliers, and their inverses for parsing input.
  @km_to_mi Decimal.new("0.621371")
  @mi_to_km Decimal.new("1.609344")
  @l_to_gal Decimal.new("0.264172")
  @gal_to_l Decimal.new("3.785412")

  # --- distance (stored in km) ---

  def distance(nil, _org), do: "—"
  def distance(km, %{unit_system: :imperial}), do: "#{number(convert(km, @km_to_mi))} mi"
  def distance(km, _org), do: "#{number(km)} km"

  def distance_unit(%{unit_system: :imperial}), do: "mi"
  def distance_unit(_org), do: "km"

  @doc """
  A stored (km) distance as a `Decimal` in the org's unit — the number behind
  `distance/2`, without formatting. Useful for per-unit maths like cost-per-distance.
  """
  def distance_value(nil, _org), do: nil
  def distance_value(km, %{unit_system: :imperial}), do: rescale(km, @km_to_mi)
  def distance_value(km, _org), do: to_decimal(km)

  @doc "Parse a distance the user entered in their unit back to kilometres."
  def to_canonical_distance(nil, _org), do: nil
  def to_canonical_distance("", _org), do: nil
  def to_canonical_distance(value, %{unit_system: :imperial}), do: rescale(value, @mi_to_km)
  def to_canonical_distance(value, _org), do: to_decimal(value)

  @doc """
  A canonical distance rendered for a number input in the org's unit — plain, ungrouped
  and unsuffixed (metric shows the stored km as-is; imperial converts km → mi). A string
  the user is mid-typing is passed straight back so their keystrokes aren't rewritten.
  """
  def distance_input(value, org), do: to_input(value, &display_distance(&1, org))

  # --- volume (stored in litres) ---

  def volume(nil, _org), do: "—"
  def volume(litres, %{unit_system: :imperial}), do: "#{number(convert(litres, @l_to_gal))} gal"
  def volume(litres, _org), do: "#{number(litres)} L"

  def volume_unit(%{unit_system: :imperial}), do: "gal"
  def volume_unit(_org), do: "L"

  @doc "A stored (litre) volume as a `Decimal` in the org's unit (number behind `volume/2`)."
  def volume_value(nil, _org), do: nil
  def volume_value(litres, %{unit_system: :imperial}), do: rescale(litres, @l_to_gal)
  def volume_value(litres, _org), do: to_decimal(litres)

  @doc "Parse a volume the user entered in their unit back to litres."
  def to_canonical_volume(nil, _org), do: nil
  def to_canonical_volume("", _org), do: nil
  def to_canonical_volume(value, %{unit_system: :imperial}), do: rescale(value, @gal_to_l)
  def to_canonical_volume(value, _org), do: to_decimal(value)

  @doc "A canonical volume rendered for a number input in the org's unit (see `distance_input/2`)."
  def volume_input(value, org), do: to_input(value, &display_volume(&1, org))

  @doc """
  Fuel economy from a canonical distance (km) and volume (litres), in the org's unit —
  `L/100km` for metric, `mpg` for imperial. Returns "—" when it can't be computed
  (missing or non-positive distance/volume).
  """
  def fuel_economy(distance_km, volume_l, org)

  def fuel_economy(%Decimal{} = distance_km, %Decimal{} = volume_l, org) do
    if positive?(distance_km) and positive?(volume_l) do
      economy(distance_km, volume_l, org)
    else
      "—"
    end
  end

  def fuel_economy(_distance_km, _volume_l, _org), do: "—"

  defp economy(distance_km, volume_l, %{unit_system: :imperial}) do
    miles = Decimal.mult(distance_km, @km_to_mi)
    gallons = Decimal.mult(volume_l, @l_to_gal)
    "#{number(Decimal.div(miles, gallons))} mpg"
  end

  defp economy(distance_km, volume_l, _org) do
    per_100km = volume_l |> Decimal.div(distance_km) |> Decimal.mult(100)
    "#{number(per_100km)} L/100km"
  end

  defp positive?(%Decimal{} = value), do: Decimal.compare(value, Decimal.new(0)) == :gt

  # --- form params ---

  @doc """
  Convert the named unit-bearing fields of a params map from the org's display unit back
  to canonical storage before the form casts them. `fields` maps string param keys to
  `:distance` or `:volume`; missing or blank keys are left untouched. For metric orgs this
  is a no-op beyond normalising the number's text.
  """
  def to_canonical_params(params, fields, org) when is_map(params) do
    Enum.reduce(fields, params, fn {key, kind}, acc ->
      case Map.get(acc, key) do
        value when value in [nil, ""] -> acc
        value -> Map.put(acc, key, canonical_param(kind, value, org))
      end
    end)
  end

  defp canonical_param(:distance, value, org), do: plain(to_canonical_distance(value, org))
  defp canonical_param(:volume, value, org), do: plain(to_canonical_volume(value, org))

  # --- dates & datetimes (stored in UTC) ---

  def date(nil, _org), do: "—"
  def date(%Date{} = date, org), do: Calendar.strftime(date, date_pattern(org))
  def date(%DateTime{} = datetime, org), do: date(DateTime.to_date(shift(datetime, org)), org)

  def datetime(nil, _org), do: "—"

  def datetime(%DateTime{} = datetime, org) do
    Calendar.strftime(shift(datetime, org), "#{date_pattern(org)} %H:%M")
  end

  # --- numbers & money ---

  def number(nil), do: "—"
  def number(%Decimal{} = value), do: value |> tidy() |> Localize.Number.to_string!()
  def number(value) when is_number(value), do: Localize.Number.to_string!(value)

  def money(nil), do: "—"
  def money(%Money{} = money), do: Money.to_string!(money)

  @doc "The org's default currency code, e.g. for new money inputs."
  def default_currency(%{currency: currency}), do: currency

  # --- internals ---

  # Convert then round to one decimal place, dropping a trailing .0 (for display).
  defp convert(value, factor), do: value |> to_decimal() |> Decimal.mult(factor) |> tidy()

  # Convert keeping two decimals, for round-tripping input/storage without visible drift.
  defp rescale(value, factor),
    do: value |> to_decimal() |> Decimal.mult(factor) |> Decimal.round(2)

  defp display_distance(km, %{unit_system: :imperial}), do: plain(rescale(km, @km_to_mi))
  defp display_distance(km, _org), do: plain(km)

  defp display_volume(litres, %{unit_system: :imperial}), do: plain(rescale(litres, @l_to_gal))
  defp display_volume(litres, _org), do: plain(litres)

  # An input value: nil → blank, a mid-typing string is left as-is, a stored number is
  # converted to the org's display unit.
  defp to_input(nil, _to_display), do: ""
  defp to_input(value, _to_display) when is_binary(value), do: value
  defp to_input(value, to_display), do: to_display.(to_decimal(value))

  # A plain decimal string: no grouping, no scientific notation, trailing zeros dropped.
  defp plain(nil), do: ""

  defp plain(%Decimal{} = decimal),
    do: decimal |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp tidy(%Decimal{} = decimal), do: decimal |> Decimal.round(1) |> Decimal.normalize()

  defp to_decimal(%Decimal{} = decimal), do: decimal
  defp to_decimal(value) when is_number(value), do: Decimal.new(to_string(value))

  defp to_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _rest} -> decimal
      :error -> Decimal.new(0)
    end
  end

  # Shift a UTC datetime into the org's timezone, falling back to UTC if it's unknown.
  defp shift(datetime, %{timezone: timezone}) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, local} -> local
      _ -> datetime
    end
  end

  defp shift(datetime, _org), do: datetime

  defp date_pattern(%{date_format: :us}), do: "%m/%d/%Y"
  defp date_pattern(%{date_format: :eu}), do: "%d/%m/%Y"
  defp date_pattern(%{date_format: :long}), do: "%B %-d, %Y"
  defp date_pattern(_org), do: "%Y-%m-%d"
end
