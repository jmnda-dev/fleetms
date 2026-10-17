defmodule Fleetms.Maintenance.ServiceGroup.Changes.SyncGroupReminders do
  @moduledoc """
  Keeps a service group's reminders in sync with its schedule lines and member
  vehicles. Runs `after_action` on create/update, once the schedules and membership
  are persisted.

  For every (schedule line × member vehicle) pair it ensures a `ServiceReminder`
  exists, linked to that schedule and stamped with its intervals:

    * no reminder yet for that (vehicle, task) → **create** one (baselined from the
      vehicle's current mileage);
    * one already exists (manual or from this group) → **update** its intervals and
      claim it for the schedule, without disturbing its last-completed baseline.

  Group reminders whose (vehicle, task) pair is no longer wanted — because the
  vehicle left the group — are **destroyed**. Reminders orphaned by a *deleted*
  schedule are removed by the FK cascade, so they need no handling here.

  Runs unauthorized: the group action itself is already authorized, and this is an
  internal cascade the actor shouldn't need per-reminder permissions for.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Fleetms.Maintenance

  @interval_keys [
    :mileage_interval,
    :time_interval,
    :time_interval_unit,
    :mileage_threshold,
    :time_threshold_days
  ]

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, group ->
      sync(group, tenant: context.tenant, authorize?: false)
      {:ok, group}
    end)
  end

  defp sync(group, opts) do
    group = Ash.load!(group, [:schedules, :vehicles], opts)
    vehicle_ids = Enum.map(group.vehicles, & &1.id)
    schedule_ids = Enum.map(group.schedules, & &1.id)

    desired = for s <- group.schedules, vid <- vehicle_ids, do: {vid, s.service_task_id, s}
    desired_keys = MapSet.new(desired, fn {vid, tid, _s} -> {vid, tid} end)

    existing = load_existing(vehicle_ids, group.schedules, opts)

    Enum.each(desired, fn {vid, tid, schedule} ->
      upsert_reminder(Map.get(existing, {vid, tid}), vid, tid, schedule, opts)
    end)

    prune_removed(schedule_ids, desired_keys, opts)
  end

  # Reminders that already exist for any of the (member vehicle, scheduled task)
  # combinations — whether created manually or by this group — keyed for lookup.
  defp load_existing([], _schedules, _opts), do: %{}

  defp load_existing(vehicle_ids, schedules, opts) do
    task_ids = schedules |> Enum.map(& &1.service_task_id) |> Enum.uniq()

    Maintenance.ServiceReminder
    |> Ash.Query.filter(vehicle_id in ^vehicle_ids and service_task_id in ^task_ids)
    |> Ash.read!(opts)
    |> Map.new(&{{&1.vehicle_id, &1.service_task_id}, &1})
  end

  defp upsert_reminder(nil, vehicle_id, task_id, schedule, opts) do
    attrs =
      schedule
      |> interval_attrs()
      |> Map.merge(%{
        vehicle_id: vehicle_id,
        service_task_id: task_id,
        service_group_schedule_id: schedule.id
      })

    Maintenance.create_service_reminder!(attrs, opts)
  end

  defp upsert_reminder(reminder, _vehicle_id, _task_id, schedule, opts) do
    attrs = Map.put(interval_attrs(schedule), :service_group_schedule_id, schedule.id)
    Maintenance.update_service_reminder!(reminder, attrs, opts)
  end

  # Destroy this group's reminders whose (vehicle, task) is no longer wanted.
  defp prune_removed([], _desired_keys, _opts), do: :ok

  defp prune_removed(schedule_ids, desired_keys, opts) do
    Maintenance.ServiceReminder
    |> Ash.Query.filter(service_group_schedule_id in ^schedule_ids)
    |> Ash.read!(opts)
    |> Enum.reject(&MapSet.member?(desired_keys, {&1.vehicle_id, &1.service_task_id}))
    |> Enum.each(&Maintenance.delete_service_reminder!(&1, opts))
  end

  defp interval_attrs(schedule), do: Map.take(schedule, @interval_keys)
end
