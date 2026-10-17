defmodule Fleetms.FuelManagement.Economy do
  @moduledoc """
  Derived fuel-economy for a single vehicle, computed from its fuel entries.

  Economy is measured "fill-to-fill": for each entry after the first, the distance
  covered since the previous fill (odometer delta) is attributed to the fuel put in
  at this fill, giving `distance ÷ quantity` (e.g. km per litre / km per kWh). The
  earliest entry has no prior reading, so it has no distance or economy.

  This is intentionally computed in Elixir over the vehicle's ordered entries
  rather than in SQL: the calculation is inherently sequential (each row depends on
  the one before), and money totals are kept per-currency (fuel entries can each
  carry their own currency, which don't sum together).
  """
  alias Fleetms.FuelManagement

  @type row :: %{entry: struct(), distance: Decimal.t() | nil, economy: Decimal.t() | nil}

  @doc """
  Loads a vehicle's fuel entries and returns per-entry economy plus a summary.

  `opts` is forwarded to the read (pass `scope:`). Entry rows are returned newest
  first for display; `monthly_volume` is oldest first for charting.
  """
  @spec for_vehicle(Ecto.UUID.t(), keyword()) :: %{
          rows: [row()],
          summary: map(),
          monthly_volume: [%{label: String.t(), volume: Decimal.t()}]
        }
  def for_vehicle(vehicle_id, opts) do
    entries = FuelManagement.list_vehicle_fuel_entries!(vehicle_id, opts)

    # Oldest → newest by odometer (with refueled_at as a tiebreaker) so each entry
    # can look back at the previous odometer reading.
    chronological = Enum.sort_by(entries, &{Decimal.to_float(&1.odometer), &1.refueled_at})

    rows = compute_rows(chronological)

    %{
      rows: Enum.reverse(rows),
      summary: summarize(rows),
      monthly_volume: monthly_volume(chronological)
    }
  end

  # Walk oldest→newest, attributing each odometer delta to the current fill.
  defp compute_rows(chronological) do
    {rows, _prev} =
      Enum.map_reduce(chronological, nil, fn entry, prev ->
        {distance, economy} = distance_and_economy(entry, prev)
        {%{entry: entry, distance: distance, economy: economy}, entry}
      end)

    rows
  end

  defp distance_and_economy(_entry, nil), do: {nil, nil}

  defp distance_and_economy(entry, prev) do
    distance = Decimal.sub(entry.odometer, prev.odometer)

    cond do
      not positive?(distance) -> {nil, nil}
      not positive?(entry.quantity) -> {distance, nil}
      true -> {distance, Decimal.round(Decimal.div(distance, entry.quantity), 2)}
    end
  end

  defp summarize(rows) do
    measured = Enum.filter(rows, &(&1.distance != nil))

    total_volume = sum_decimal(Enum.map(rows, & &1.entry.quantity))
    total_distance = sum_decimal(Enum.map(measured, & &1.distance))
    measured_volume = sum_decimal(Enum.map(measured, & &1.entry.quantity))

    %{
      entry_count: length(rows),
      total_volume: total_volume,
      total_distance: total_distance,
      avg_economy: average_economy(total_distance, measured_volume),
      spend: spend_by_currency(rows)
    }
  end

  defp average_economy(total_distance, measured_volume) do
    if positive?(measured_volume) do
      Decimal.round(Decimal.div(total_distance, measured_volume), 2)
    end
  end

  # Group costs by currency and sum each group — per-entry currencies never mix.
  defp spend_by_currency(rows) do
    rows
    |> Enum.map(& &1.entry.cost)
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {_currency, monies} -> Enum.reduce(monies, &Money.add!(&1, &2)) end)
    |> Enum.sort_by(&to_string(&1.currency))
  end

  defp monthly_volume(chronological) do
    chronological
    |> Enum.group_by(fn entry -> {entry.refueled_at.year, entry.refueled_at.month} end)
    |> Enum.map(fn {{year, month}, entries} ->
      %{
        year: year,
        month: month,
        label: "#{month_abbr(month)} #{year}",
        volume: sum_decimal(Enum.map(entries, & &1.quantity))
      }
    end)
    |> Enum.sort_by(&{&1.year, &1.month})
  end

  defp sum_decimal(decimals), do: Enum.reduce(decimals, Decimal.new(0), &Decimal.add/2)

  defp positive?(%Decimal{} = d), do: Decimal.gt?(d, 0)
  defp positive?(_), do: false

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  defp month_abbr(month), do: Enum.at(@months, month - 1)
end
