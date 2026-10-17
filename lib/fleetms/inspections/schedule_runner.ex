defmodule Fleetms.Inspections.ScheduleRunner do
  @moduledoc """
  Generates and closes `InspectionAssignment`s for an organization's
  `InspectionSchedule`s.

  Two entry points, both actor-less (system):

    * `generate_for_tenant/1` — run daily by the schedule's Oban job. For each
      active schedule with no open assignment, it creates the next one, keeping at
      most one open assignment per schedule (so missed periods become a single
      overdue item, not a backlog). The next due date is the previous assignment's
      due date plus the schedule's interval, or the schedule's `start_date` for the
      very first.

    * `complete_matching/2` — called after an inspection is submitted. It closes the
      oldest open assignment for the same vehicle and form, linking the inspection.
      Submitting an unscheduled inspection simply matches nothing.
  """
  require Ash.Query
  require Logger

  alias Fleetms.Inspections
  alias Fleetms.Inspections.{InspectionAssignment, InspectionSchedule}

  @doc "Tops up open assignments for all active schedules in `tenant`. Returns the count created."
  def generate_for_tenant(tenant) do
    InspectionSchedule
    |> Ash.Query.filter(active == true)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.count(&generate_for_schedule(&1, tenant))
  end

  # Returns true if it created an assignment, false if one was already open.
  defp generate_for_schedule(schedule, tenant) do
    if open_assignment?(schedule, tenant) do
      false
    else
      Inspections.generate_inspection_assignment!(
        %{
          due_on: next_due_on(schedule, tenant),
          schedule_id: schedule.id,
          vehicle_id: schedule.vehicle_id,
          inspection_form_id: schedule.inspection_form_id,
          assigned_to_id: schedule.assigned_to_id
        },
        tenant: tenant,
        authorize?: false
      )

      true
    end
  end

  defp open_assignment?(schedule, tenant) do
    InspectionAssignment
    |> Ash.Query.filter(schedule_id == ^schedule.id and is_nil(completed_at))
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.any?()
  end

  defp next_due_on(schedule, tenant) do
    case latest_assignment(schedule, tenant) do
      nil -> schedule.start_date
      assignment -> Date.add(assignment.due_on, schedule.interval_days)
    end
  end

  defp latest_assignment(schedule, tenant) do
    InspectionAssignment
    |> Ash.Query.filter(schedule_id == ^schedule.id)
    |> Ash.Query.sort(due_on: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> List.first()
  end

  @doc """
  Closes the oldest open assignment matching `inspection`'s vehicle and form, if
  any. Best-effort — a failure here must not fail the submit.
  """
  def complete_matching(inspection, tenant) do
    case oldest_open_match(inspection, tenant) do
      nil ->
        :ok

      assignment ->
        Inspections.complete_inspection_assignment!(assignment, %{inspection_id: inspection.id},
          tenant: tenant,
          authorize?: false
        )

        :ok
    end
  rescue
    error ->
      Logger.error(
        "Failed to complete inspection assignment for inspection #{inspection.id}: " <>
          Exception.message(error)
      )

      :ok
  end

  defp oldest_open_match(inspection, tenant) do
    InspectionAssignment
    |> Ash.Query.filter(
      vehicle_id == ^inspection.vehicle_id and
        inspection_form_id == ^inspection.inspection_form_id and
        is_nil(completed_at)
    )
    |> Ash.Query.sort(due_on: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> List.first()
  end
end
