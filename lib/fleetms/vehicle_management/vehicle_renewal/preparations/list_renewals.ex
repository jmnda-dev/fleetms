defmodule Fleetms.VehicleManagement.VehicleRenewal.Preparations.ListRenewals do
  @moduledoc """
  Applies the renewal list's free-text search, faceted filters and sort to the
  `:list` read action, and loads the derived `status` plus the related vehicle and
  renewal type used in the listing.

  `status` is an expression calculation, so it can be both filtered and sorted on
  in the database. Search is trigram-based across the vehicle name, renewal type
  and comments.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :due_date
    sort_order = Ash.Query.get_argument(query, :sort_order) || :asc

    query
    |> Ash.Query.load([:status, :vehicle, :renewal_type])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q

  defp apply_filter(q, "statuses", v), do: Ash.Query.filter(q, status in ^List.wrap(v))
  defp apply_filter(q, "vehicle_id", id), do: Ash.Query.filter(q, vehicle_id == ^id)
  defp apply_filter(q, "renewal_type_id", id), do: Ash.Query.filter(q, renewal_type_id == ^id)

  defp apply_filter(q, "due_from", v),
    do: with_date(q, v, &Ash.Query.filter(&1, due_date >= ^&2))

  defp apply_filter(q, "due_to", v),
    do: with_date(q, v, &Ash.Query.filter(&1, due_date <= ^&2))

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(vehicle.name, ^search) > ^@search_threshold or
        trigram_similarity(renewal_type.name, ^search) > ^@search_threshold or
        trigram_similarity(comments, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query

  defp with_date(query, value, fun) do
    case to_date(value) do
      nil -> query
      date -> fun.(query, date)
    end
  end

  defp to_date(%Date{} = date), do: date

  defp to_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp to_date(_), do: nil
end
