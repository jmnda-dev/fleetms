defmodule Fleetms.Search do
  @moduledoc """
  Cross-resource search behind the ⌘K command palette.

  Fans a single query out to the main record types a user jumps to — vehicles,
  issues and work orders — reusing each resource's existing trigram-based `:list`
  search. Because it goes through the normal read actions with the caller's
  scope, results are already limited to the current tenant and to what the
  viewer is allowed to see.

  Returns a list of groups (empty groups dropped), each `%{type: atom, items:
  [...]}`; the web layer maps `type` to a heading, icon and route.
  """
  alias Fleetms.Maintenance
  alias Fleetms.VehicleIssues
  alias Fleetms.VehicleManagement

  @per_type 5
  @min_length 2

  @type item :: %{id: String.t(), primary: String.t(), secondary: String.t() | nil}
  @type group :: %{type: atom(), items: [item()]}

  @doc """
  Runs `query` across the searchable resources for `scope`. Queries shorter than
  two characters return no groups, so an incidental keystroke isn't a full scan.
  """
  @spec run(String.t() | any(), Fleetms.Scope.t()) :: [group()]
  def run(query, scope) when is_binary(query) do
    query = String.trim(query)

    if String.length(query) < @min_length do
      []
    else
      [vehicles(query, scope), issues(query, scope), work_orders(query, scope)]
      |> Enum.reject(&(&1.items == []))
    end
  end

  def run(_query, _scope), do: []

  defp vehicles(query, scope) do
    items =
      case VehicleManagement.list_vehicles(%{search_query: query},
             scope: scope,
             page: [limit: @per_type]
           ) do
        {:ok, %{results: results}} ->
          Enum.map(results, &%{id: &1.id, primary: &1.name, secondary: &1.license_plate})

        _ ->
          []
      end

    %{type: :vehicle, items: items}
  end

  defp issues(query, scope) do
    items =
      case VehicleIssues.list_issues(%{search_query: query},
             scope: scope,
             load: [:vehicle],
             page: [limit: @per_type]
           ) do
        {:ok, %{results: results}} ->
          Enum.map(results, fn issue ->
            %{
              id: issue.id,
              primary: "##{issue.issue_number} · #{issue.title}",
              secondary: issue.vehicle && issue.vehicle.name
            }
          end)

        _ ->
          []
      end

    %{type: :issue, items: items}
  end

  defp work_orders(query, scope) do
    items =
      case Maintenance.list_work_orders(%{search_query: query},
             scope: scope,
             page: [limit: @per_type]
           ) do
        {:ok, %{results: results}} ->
          Enum.map(results, fn wo ->
            %{id: wo.id, primary: "WO ##{wo.work_order_number}", secondary: wo.description}
          end)

        _ ->
          []
      end

    %{type: :work_order, items: items}
  end
end
