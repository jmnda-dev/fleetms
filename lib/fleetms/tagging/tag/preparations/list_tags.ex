defmodule Fleetms.Tagging.Tag.Preparations.ListTags do
  @moduledoc """
  Applies the tag list's free-text search over the name, an optional colour filter,
  and the requested sort; loads the `usage_count` shown on the management page.
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
    |> Ash.Query.load([:usage_count])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q
  defp apply_filter(q, "colors", v), do: Ash.Query.filter(q, color in ^coerce_atoms(v))
  defp apply_filter(q, _key, _value), do: q

  # color is an Ash enum column; string values from the URL need to be atoms.
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

  # ci_string name — compare against the search as text.
  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(fragment("?::text", name), ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query
end
