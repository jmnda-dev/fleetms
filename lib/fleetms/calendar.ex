defmodule Fleetms.Calendar do
  @moduledoc """
  A unified "what's due" feed for the calendar page.

  Pulls the dated items scattered across the app — service reminders, renewals,
  issues and scheduled inspections — into one normalised list of events. Each
  source is fetched through its existing `:list` action with the caller's scope,
  so events are tenant-scoped and respect the viewer's permissions (a source the
  user can't read simply contributes nothing).

  Events are plain maps: `%{id, type, date, title, subtitle}` where `type` is one
  of `:reminder | :renewal | :issue | :inspection`. The web layer maps `type` to
  a colour, icon and route.
  """
  alias Fleetms.Drivers
  alias Fleetms.Inspections
  alias Fleetms.Maintenance
  alias Fleetms.VehicleIssues
  alias Fleetms.VehicleManagement

  # Fleets are small; pull a generous page and bucket by day in memory rather
  # than teach each list action a date-range filter.
  @limit 1000

  @type event :: %{
          id: String.t(),
          type: :reminder | :renewal | :issue | :inspection | :license,
          date: Date.t(),
          title: String.t(),
          subtitle: String.t() | nil
        }

  @doc """
  All events whose date falls within `from..to` (inclusive), for `scope`.
  """
  @spec events(Fleetms.Scope.t(), Date.t(), Date.t()) :: [event()]
  def events(scope, %Date{} = from, %Date{} = to) do
    (reminders(scope) ++ renewals(scope) ++ issues(scope) ++ inspections(scope) ++ licenses(scope))
    |> Enum.filter(&in_range?(&1.date, from, to))
  end

  defp in_range?(nil, _from, _to), do: false

  defp in_range?(%Date{} = date, from, to),
    do: Date.compare(date, from) != :lt and Date.compare(date, to) != :gt

  defp reminders(scope) do
    Maintenance.list_service_reminders(%{}, scope: scope, page: [limit: @limit])
    |> results()
    |> Enum.map(fn reminder ->
      %{
        id: reminder.id,
        type: :reminder,
        date: reminder.next_due_date,
        title: reminder.service_task_name || "Service reminder",
        subtitle: reminder.vehicle_name
      }
    end)
  end

  defp renewals(scope) do
    VehicleManagement.list_vehicle_renewals(%{}, scope: scope, page: [limit: @limit])
    |> results()
    |> Enum.map(fn renewal ->
      %{
        id: renewal.id,
        type: :renewal,
        date: renewal.due_date,
        title: (renewal.renewal_type && renewal.renewal_type.name) || "Renewal",
        subtitle: renewal.vehicle && renewal.vehicle.name
      }
    end)
  end

  defp issues(scope) do
    VehicleIssues.list_issues(%{}, scope: scope, load: [:vehicle], page: [limit: @limit])
    |> results()
    |> Enum.map(fn issue ->
      %{
        id: issue.id,
        type: :issue,
        date: issue.due_date,
        title: "##{issue.issue_number} · #{issue.title}",
        subtitle: issue.vehicle && issue.vehicle.name
      }
    end)
  end

  defp inspections(scope) do
    Inspections.list_inspection_assignments(%{}, scope: scope, page: [limit: @limit])
    |> results()
    |> Enum.map(fn assignment ->
      %{
        id: assignment.id,
        type: :inspection,
        date: assignment.due_on,
        title: (assignment.inspection_form && assignment.inspection_form.title) || "Inspection",
        subtitle: assignment.vehicle && assignment.vehicle.name
      }
    end)
  end

  defp licenses(scope) do
    Drivers.list_drivers(%{}, scope: scope, page: [limit: @limit])
    |> results()
    |> Enum.map(fn driver ->
      %{
        id: driver.id,
        type: :license,
        date: driver.license_expiry,
        title: "#{driver.first_name} #{driver.last_name} · licence",
        subtitle: driver.license_number
      }
    end)
  end

  # Some list actions paginate and some don't; accept either shape.
  defp results({:ok, %{results: results}}), do: results
  defp results({:ok, results}) when is_list(results), do: results
  defp results(_), do: []
end
