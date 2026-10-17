defmodule FleetmsWeb.ListView do
  @moduledoc """
  Small helpers shared by the list/index LiveViews, which all keep their
  search / filter / sort / page state in the URL query string.

  A page typically does:

      import FleetmsWeb.ListView

      @limit 20
      @sortable ~w(name inserted_at)a

      sort_by = sort_by(params["sort"], @sortable, :name)
      sort_order = sort_order(params["dir"])
      page = page_number(params["page"])

  and, on a sort click, `next_sort/3` to flip direction.
  """

  @doc "Parses a positive page number from a param, defaulting to 1."
  def page_number(value) do
    case Integer.parse(to_string(value)) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  @doc "Coerces a direction param to `:asc` or `:desc` (default `:desc`)."
  def sort_order("asc"), do: :asc
  def sort_order(_), do: :desc

  @doc """
  Resolves a sort param against the allowed `sortable` atoms, falling back to
  `default` when the param isn't one of them.
  """
  def sort_by(value, sortable, default) when is_list(sortable) do
    Enum.find(sortable, default, &(to_string(&1) == value))
  end

  @doc """
  Given the current sort field/order and a clicked field, returns the next
  `{sort_string, dir_string}`: a new field sorts ascending, the same field flips.
  """
  def next_sort(current_field, current_order, clicked_field) do
    cond do
      clicked_field != current_field -> {to_string(clicked_field), "asc"}
      current_order == :asc -> {to_string(clicked_field), "desc"}
      true -> {to_string(clicked_field), "asc"}
    end
  end

  @doc "nil/empty-string -> nil, otherwise the value (handy for cleaning params)."
  def nilify(nil), do: nil
  def nilify(""), do: nil
  def nilify(value), do: value

  @doc "Total number of pages for a count at the given page size."
  def total_pages(count, limit), do: max(1, ceil(count / limit))

  @doc """
  Drops nil / empty-string / empty-list values from a params map (so the URL
  stays clean) and returns a `%{}` map.
  """
  def prune(params) do
    params
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end
end
