defmodule Fleetms.VehicleManagement.VehicleAssignment.Preparations.ListAssignments do
  @moduledoc """
  Applies the assignment list's free-text search, faceted filters and sort to the
  `:list` read action, and loads the derived `status` plus the related vehicle and
  assignee used in the listing.

  Search is trigram-based across the vehicle name and the assignee's name and
  comments. Filters come from the drawer as a map and are coerced/ignored
  defensively. `status` is a calculation, so it can be both filtered and sorted on.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :start_datetime
    sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

    query
    |> Ash.Query.load([
      :status,
      :driver,
      assignee: [:email, profile: [:first_name, :last_name]],
      vehicle: []
    ])
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
  defp apply_filter(q, "assignee_id", id), do: Ash.Query.filter(q, assignee_id == ^id)

  defp apply_filter(q, "start_from", v),
    do: with_date(q, v, &Ash.Query.filter(&1, start_datetime >= ^&2))

  defp apply_filter(q, "start_to", v),
    do: with_date(q, v, &Ash.Query.filter(&1, start_datetime <= ^&2))

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(vehicle.name, ^search) > ^@search_threshold or
        trigram_similarity(assignee.profile.first_name, ^search) > ^@search_threshold or
        trigram_similarity(assignee.profile.last_name, ^search) > ^@search_threshold or
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
