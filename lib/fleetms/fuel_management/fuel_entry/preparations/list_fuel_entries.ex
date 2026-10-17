defmodule Fleetms.FuelManagement.FuelEntry.Preparations.ListFuelEntries do
  @moduledoc """
  Applies the fuel log's free-text search, faceted filters and sort to the `:list`
  read action, and loads the related vehicle and the member who refueled.

  Search is trigram-based across the vehicle name, location and notes. Cost isn't
  offered as a sort because entries can be in different currencies, which don't
  order meaningfully against each other.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :refueled_at
    sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

    query
    |> Ash.Query.load([:vehicle, refueled_by: [:profile]])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q

  defp apply_filter(q, "vehicle_id", id), do: Ash.Query.filter(q, vehicle_id == ^id)
  defp apply_filter(q, "refueled_by_id", id), do: Ash.Query.filter(q, refueled_by_id == ^id)

  defp apply_filter(q, "fuel_types", v),
    do: Ash.Query.filter(q, fuel_type in ^List.wrap(v))

  defp apply_filter(q, "payment_methods", v),
    do: Ash.Query.filter(q, payment_method in ^List.wrap(v))

  defp apply_filter(q, "refueled_from", v),
    do: with_date(q, v, &Ash.Query.filter(&1, refueled_at >= ^&2))

  defp apply_filter(q, "refueled_to", v),
    do: with_date(q, v, &Ash.Query.filter(&1, refueled_at <= ^&2))

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(vehicle.name, ^search) > ^@search_threshold or
        trigram_similarity(location, ^search) > ^@search_threshold or
        trigram_similarity(notes, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query

  defp with_date(query, value, fun) do
    case to_datetime(value) do
      nil -> query
      datetime -> fun.(query, datetime)
    end
  end

  defp to_datetime(%DateTime{} = datetime), do: datetime
  defp to_datetime(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00])

  defp to_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> with_iso_date(value)
    end
  end

  defp to_datetime(_), do: nil

  defp with_iso_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00])
      _ -> nil
    end
  end
end
