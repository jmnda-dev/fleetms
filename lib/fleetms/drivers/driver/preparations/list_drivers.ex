defmodule Fleetms.Drivers.Driver.Preparations.ListDrivers do
  @moduledoc """
  Applies the driver list's free-text search, status filter and sort. Search is
  trigram-based across the driver's name, licence number and phone.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :last_name
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
  defp apply_filter(q, "statuses", v), do: Ash.Query.filter(q, status in ^List.wrap(v))
  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(first_name, ^search) > ^@search_threshold or
        trigram_similarity(last_name, ^search) > ^@search_threshold or
        trigram_similarity(license_number, ^search) > ^@search_threshold or
        trigram_similarity(phone, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query
end
