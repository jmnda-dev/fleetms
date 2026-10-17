defmodule Fleetms.Maintenance.ServiceTask.Preparations.ListServiceTasks do
  @moduledoc """
  Applies the service-task list's free-text search over name and description,
  plus the requested sort.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    search = Ash.Query.get_argument(query, :search_query)
    sort_by = Ash.Query.get_argument(query, :sort_by) || :name
    sort_order = Ash.Query.get_argument(query, :sort_order) || :asc

    query
    |> Ash.Query.sort([{sort_by, sort_order}])
    |> apply_search(search)
  end

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(name, ^search) > ^@search_threshold or
        trigram_similarity(description, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query
end
