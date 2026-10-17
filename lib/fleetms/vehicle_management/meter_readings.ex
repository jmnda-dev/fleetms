defmodule Fleetms.VehicleManagement.MeterReadings do
  @moduledoc """
  Builds a vehicle's odometer history by gathering the readings already captured
  elsewhere — on fuel entries, issues and work orders — into one timeline.

  Nothing is stored; this reads through the existing per-vehicle list actions with
  the caller's scope, so the history is tenant-scoped and respects permissions (a
  source the user can't read simply contributes nothing). Readings are returned
  newest-first as `%{date, value, source, label}` maps; `value` is a Decimal in
  the stored canonical unit (km).
  """
  alias Fleetms.FuelManagement
  alias Fleetms.Maintenance
  alias Fleetms.VehicleIssues

  @type reading :: %{
          date: DateTime.t(),
          value: Decimal.t(),
          source: :fuel | :issue | :work_order,
          label: String.t()
        }

  @spec for_vehicle(Fleetms.Scope.t(), String.t()) :: [reading()]
  def for_vehicle(scope, vehicle_id) do
    (fuel(scope, vehicle_id) ++ issues(scope, vehicle_id) ++ work_orders(scope, vehicle_id))
    |> Enum.reject(&(is_nil(&1.value) or is_nil(&1.date)))
    |> Enum.sort_by(& &1.date, {:desc, DateTime})
  end

  defp fuel(scope, vehicle_id) do
    safe_list(fn -> FuelManagement.list_vehicle_fuel_entries(vehicle_id, scope: scope) end)
    |> Enum.map(&%{date: &1.refueled_at, value: &1.odometer, source: :fuel, label: "Fuel entry"})
  end

  defp issues(scope, vehicle_id) do
    safe_list(fn -> VehicleIssues.list_vehicle_issues(vehicle_id, scope: scope) end)
    |> Enum.map(
      &%{
        date: &1.reported_at,
        value: &1.mileage,
        source: :issue,
        label: "Issue ##{&1.issue_number}"
      }
    )
  end

  defp work_orders(scope, vehicle_id) do
    safe_list(fn -> Maintenance.list_vehicle_work_orders(vehicle_id, scope: scope) end)
    |> Enum.map(
      &%{
        date: &1.issued_at,
        value: &1.mileage,
        source: :work_order,
        label: "Work order ##{&1.work_order_number}"
      }
    )
  end

  # Runs a list function, tolerating a forbidden/empty result and both the
  # paginated and plain-list shapes.
  defp safe_list(fun) do
    case fun.() do
      {:ok, %{results: results}} -> results
      {:ok, results} when is_list(results) -> results
      results when is_list(results) -> results
      _ -> []
    end
  end
end
