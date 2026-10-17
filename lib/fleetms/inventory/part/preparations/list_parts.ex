defmodule Fleetms.Inventory.Part.Preparations.ListParts do
  @moduledoc """
  Applies the parts list's free-text search, faceted filters and sort to the
  `:list` read action, and loads the derived `stock_status` plus the category used
  in the listing.

  `stock_status` is an expression calculation, so it can be both filtered and
  sorted on in the database. Search is trigram-based across the part number,
  names, manufacturer and description.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :part_number
    sort_order = Ash.Query.get_argument(query, :sort_order) || :asc

    query
    |> Ash.Query.load([:stock_status, :total_stock, :category])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q

  defp apply_filter(q, "category_id", id), do: Ash.Query.filter(q, category_id == ^id)

  defp apply_filter(q, "statuses", v), do: Ash.Query.filter(q, stock_status in ^List.wrap(v))

  defp apply_filter(q, "track_inventory", "true"),
    do: Ash.Query.filter(q, track_inventory == true)

  defp apply_filter(q, "track_inventory", _), do: q

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(part_number, ^search) > ^@search_threshold or
        trigram_similarity(name, ^search) > ^@search_threshold or
        trigram_similarity(oem_part_number, ^search) > ^@search_threshold or
        trigram_similarity(manufacturer, ^search) > ^@search_threshold or
        trigram_similarity(category.name, ^search) > ^@search_threshold or
        trigram_similarity(description, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query
end
