defmodule Fleetms.Maintenance.WorkOrder.Preparations.ListWorkOrders do
  @moduledoc """
  Builds the work-order list query from the `list` action's arguments: applies the
  faceted filters (status, repair category, vehicle, assignee, issued-date range),
  a free-text trigram search over the number/description/vehicle, the requested
  sort, and loads what the list row shows.

  Filters come from the filter drawer as a map and are coerced/ignored defensively:
  a blank or unparseable value is simply skipped.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    filters = Ash.Query.get_argument(query, :filters) || %{}
    search = Ash.Query.get_argument(query, :search_query)
    sort_by = Ash.Query.get_argument(query, :sort_by) || :work_order_number
    sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

    query
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
    |> Ash.Query.load([
      :service_task_count,
      vehicle: [:name],
      assigned_to: [:email, profile: [:first_name, :last_name]]
    ])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", [], "All", :All], do: q

  defp apply_filter(q, "statuses", v), do: Ash.Query.filter(q, status in ^List.wrap(v))

  defp apply_filter(q, "categories", v),
    do: Ash.Query.filter(q, repair_category in ^coerce_atoms(v))

  # Back-compat with the previous single-value status filter.
  defp apply_filter(q, "status", v), do: Ash.Query.filter(q, status == ^v)
  defp apply_filter(q, "vehicle_id", id), do: Ash.Query.filter(q, vehicle_id == ^id)
  defp apply_filter(q, "assigned_to_id", id), do: Ash.Query.filter(q, assigned_to_id == ^id)

  defp apply_filter(q, "issued_from", v),
    do: with_date(q, v, &Ash.Query.filter(&1, issued_at >= ^&2))

  defp apply_filter(q, "issued_to", v),
    do: with_date(q, v, &Ash.Query.filter(&1, issued_at <= ^&2))

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(fragment("?::text", work_order_number), ^search) > ^@search_threshold or
        trigram_similarity(description, ^search) > ^@search_threshold or
        trigram_similarity(vehicle.name, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query

  # repair_category is an Ash enum column; string values from the URL need to be atoms.
  defp coerce_atoms(values) do
    values
    |> List.wrap()
    |> Enum.map(fn
      v when is_atom(v) -> v
      v when is_binary(v) -> String.to_existing_atom(v)
    end)
    |> Enum.filter(&is_atom/1)
  end

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
