defmodule Fleetms.Inspections.Inspection.Preparations.ListInspections do
  @moduledoc """
  Builds the inspection list query: a free-text trigram search over the vehicle
  name and form title, faceted filters (result, status, vehicle, form) from the
  filter drawer, the requested sort, and the loads the list row shows.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :submitted_at
    sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

    query
    |> Ash.Query.load([:failure_count, vehicle: [:name], inspection_form: [:title]])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q

  defp apply_filter(q, "results", v), do: Ash.Query.filter(q, result in ^coerce_atoms(v))
  defp apply_filter(q, "statuses", v), do: Ash.Query.filter(q, status in ^coerce_atoms(v))
  defp apply_filter(q, "vehicle_id", id), do: Ash.Query.filter(q, vehicle_id == ^id)

  defp apply_filter(q, "inspection_form_id", id),
    do: Ash.Query.filter(q, inspection_form_id == ^id)

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(vehicle.name, ^search) > ^@search_threshold or
        trigram_similarity(inspection_form.title, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query

  defp coerce_atoms(values) do
    values
    |> List.wrap()
    |> Enum.map(fn
      v when is_atom(v) -> v
      v when is_binary(v) -> safe_atom(v)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp safe_atom(v) do
    String.to_existing_atom(v)
  rescue
    ArgumentError -> nil
  end
end
