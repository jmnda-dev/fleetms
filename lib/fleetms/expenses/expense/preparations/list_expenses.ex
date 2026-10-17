defmodule Fleetms.Expenses.Expense.Preparations.ListExpenses do
  @moduledoc """
  Applies the expense list's free-text search, faceted filters and sort to the
  `:list` read action, and loads the related vehicle and vendor.

  Search is trigram-based across the vehicle name and description. Amount is
  sortable within a currency; entries in different currencies just order by the
  numeric amount, which the report layer handles per currency.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    filters = Ash.Query.get_argument(query, :filters) || %{}
    sort_by = Ash.Query.get_argument(query, :sort_by) || :expense_date
    sort_order = Ash.Query.get_argument(query, :sort_order) || :desc

    query
    |> Ash.Query.load([:vehicle, :vendor])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, q -> apply_filter(q, to_string(key), value) end)
  end

  defp apply_filter(q, _key, value) when value in [nil, "", []], do: q

  defp apply_filter(q, "vehicle_id", id), do: Ash.Query.filter(q, vehicle_id == ^id)
  defp apply_filter(q, "vendor_id", id), do: Ash.Query.filter(q, vendor_id == ^id)

  defp apply_filter(q, "categories", v), do: Ash.Query.filter(q, category in ^List.wrap(v))

  defp apply_filter(q, "from", v),
    do: with_date(q, v, &Ash.Query.filter(&1, expense_date >= ^&2))

  defp apply_filter(q, "to", v),
    do: with_date(q, v, &Ash.Query.filter(&1, expense_date <= ^&2))

  defp apply_filter(q, _key, _value), do: q

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(vehicle.name, ^search) > ^@search_threshold or
        trigram_similarity(description, ^search) > ^@search_threshold
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
