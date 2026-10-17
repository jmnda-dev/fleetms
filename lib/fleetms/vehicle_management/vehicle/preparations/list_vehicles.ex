defmodule Fleetms.VehicleManagement.Vehicle.Preparations.ListVehicles do
  @moduledoc """
  Applies the vehicle list's free-text search, faceted filters and sort to the
  `:list` read action.

  Search is trigram-based (pg_trgm) across the vehicle's name, make, model,
  licence plate and VIN, so partial and slightly-misspelled queries still match.
  Filters come from the filter drawer as a map and are coerced/ignored
  defensively — a blank or unparseable value is simply skipped.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :name
    sort_order = Ash.Query.get_argument(query, :sort_order) || :asc

    query
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q

  defp apply_filter(q, "make_id", id),
    do: Ash.Query.filter(q, vehicle_model.vehicle_make_id == ^id)

  defp apply_filter(q, "model_id", id), do: Ash.Query.filter(q, vehicle_model_id == ^id)

  defp apply_filter(q, "vehicle_group_id", id),
    do: Ash.Query.filter(q, vehicle_group_id == ^id)

  defp apply_filter(q, "year_min", v), do: with_int(q, v, &Ash.Query.filter(&1, year >= ^&2))
  defp apply_filter(q, "year_max", v), do: with_int(q, v, &Ash.Query.filter(&1, year <= ^&2))

  defp apply_filter(q, "mileage_min", v),
    do: with_int(q, v, &Ash.Query.filter(&1, mileage >= ^&2))

  defp apply_filter(q, "mileage_max", v),
    do: with_int(q, v, &Ash.Query.filter(&1, mileage <= ^&2))

  defp apply_filter(q, "statuses", v), do: Ash.Query.filter(q, status in ^List.wrap(v))
  defp apply_filter(q, "types", v), do: Ash.Query.filter(q, type in ^List.wrap(v))
  defp apply_filter(q, "categories", v), do: Ash.Query.filter(q, category in ^List.wrap(v))

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(name, ^search) > ^@search_threshold or
        trigram_similarity(vehicle_model.vehicle_make.name, ^search) > ^@search_threshold or
        trigram_similarity(vehicle_model.name, ^search) > ^@search_threshold or
        trigram_similarity(license_plate, ^search) > ^@search_threshold or
        trigram_similarity(vin, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query

  defp with_int(query, value, fun) do
    case to_integer(value) do
      nil -> query
      int -> fun.(query, int)
    end
  end

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp to_integer(_), do: nil
end
