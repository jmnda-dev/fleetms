defmodule Fleetms.Inspections.InspectionSchedule.Preparations.ListInspectionSchedules do
  @moduledoc """
  Builds the inspection-schedule list: a free-text trigram search over the vehicle
  name and form title, an optional active/paused filter, the requested sort, and the
  loads the row shows.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :inserted_at
    sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

    query
    |> Ash.Query.load([:open_assignment_count, vehicle: [:name], inspection_form: [:title]])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q
  defp apply_filter(q, "active", "true"), do: Ash.Query.filter(q, active == true)
  defp apply_filter(q, "active", "false"), do: Ash.Query.filter(q, active == false)
  defp apply_filter(q, "active", true), do: Ash.Query.filter(q, active == true)
  defp apply_filter(q, "active", false), do: Ash.Query.filter(q, active == false)
  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(vehicle.name, ^search) > ^@search_threshold or
        trigram_similarity(inspection_form.title, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query
end
