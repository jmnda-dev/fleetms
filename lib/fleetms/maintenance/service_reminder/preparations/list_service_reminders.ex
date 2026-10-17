defmodule Fleetms.Maintenance.ServiceReminder.Preparations.ListServiceReminders do
  @moduledoc """
  Builds the service-reminder list query: advanced filters (vehicle, service task,
  due status), a free-text trigram search over vehicle / service-task names, the
  requested sort, and the loads the list row shows.

  `due_status` is a live calculation; filtering on it is applied here so the list
  can show, say, only what's overdue.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @search_threshold 0.1

  @impl true
  def prepare(query, _opts, _context) do
    filters = Ash.Query.get_argument(query, :filters) || %{}
    search = Ash.Query.get_argument(query, :search_query)
    sort_by = Ash.Query.get_argument(query, :sort_by)
    sort_order = Ash.Query.get_argument(query, :sort_order)

    query
    |> Ash.Query.load([
      :due_status,
      :vehicle_mileage,
      :mileage_remaining,
      :days_remaining,
      :service_task_name,
      :vehicle_name
    ])
    |> apply_filters(filters)
    |> apply_search(search)
    |> Ash.Query.sort([{sort_by, sort_order}])
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, acc -> apply_filter(acc, key, value) end)
  end

  defp apply_filter(query, _key, value) when value in [nil, "", [], "All", :All], do: query

  defp apply_filter(query, key, value) when key in ["vehicle_id", :vehicle_id],
    do: Ash.Query.filter(query, vehicle_id == ^value)

  defp apply_filter(query, key, value) when key in ["service_task_id", :service_task_id],
    do: Ash.Query.filter(query, service_task_id == ^value)

  defp apply_filter(query, key, value) when key in ["due_status", :due_status],
    do: Ash.Query.filter(query, due_status == ^value)

  defp apply_filter(query, key, value) when key in ["due_statuses", :due_statuses],
    do: Ash.Query.filter(query, due_status in ^List.wrap(value))

  defp apply_filter(query, _key, _value), do: query

  defp apply_search(query, search) when is_binary(search) and search != "" do
    Ash.Query.filter(
      query,
      trigram_similarity(vehicle.name, ^search) > ^@search_threshold or
        trigram_similarity(service_task.name, ^search) > ^@search_threshold
    )
  end

  defp apply_search(query, _search), do: query
end
