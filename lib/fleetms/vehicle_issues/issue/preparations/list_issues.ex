defmodule Fleetms.VehicleIssues.Issue.Preparations.ListIssues do
  @moduledoc """
  Applies the issue list's free-text search, faceted filters and sort to the
  `:list` read action.

  Search is trigram-based (pg_trgm) across the issue's title, description and
  number, so partial and slightly-misspelled queries still match. Filters come
  from the filter drawer as a map and are coerced/ignored defensively — a blank
  or unparseable value is simply skipped.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :issue_number
    sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

    query
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q

  defp apply_filter(q, "statuses", v), do: Ash.Query.filter(q, status in ^List.wrap(v))
  defp apply_filter(q, "priorities", v), do: Ash.Query.filter(q, priority in ^List.wrap(v))
  defp apply_filter(q, "vehicle_id", id), do: Ash.Query.filter(q, vehicle_id == ^id)
  defp apply_filter(q, "assigned_to_id", id), do: Ash.Query.filter(q, assigned_to_id == ^id)

  defp apply_filter(q, "reported_from", v),
    do: with_date(q, v, &Ash.Query.filter(&1, reported_at >= ^&2))

  defp apply_filter(q, "reported_to", v),
    do: with_date(q, v, &Ash.Query.filter(&1, reported_at <= ^&2))

  defp apply_filter(q, "due_from", v),
    do: with_date(q, v, &Ash.Query.filter(&1, due_date >= ^&2))

  defp apply_filter(q, "due_to", v),
    do: with_date(q, v, &Ash.Query.filter(&1, due_date <= ^&2))

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(title, ^search) > ^@search_threshold or
        trigram_similarity(description, ^search) > ^@search_threshold or
        trigram_similarity(fragment("CAST(? AS VARCHAR)", issue_number), ^search) >
          ^@search_threshold
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
