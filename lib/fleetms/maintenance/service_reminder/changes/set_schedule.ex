defmodule Fleetms.Maintenance.ServiceReminder.Changes.SetSchedule do
  @moduledoc """
  Computes a service reminder's schedule.

  On `:create` and `:reset` the "last completed" point is stamped from the
  vehicle's *current* mileage and today's date (a reminder is created, and reset by
  a completed service, from where the vehicle is now). The next-due point is then
  derived from that baseline plus the intervals:

    * `next_due_mileage = last_completed_mileage + mileage_interval`
    * `next_due_date    = last_completed_date shifted by time_interval / unit`

  On a plain `:update` (editing the intervals) the baseline is left as-is and only
  the next-due points are recomputed. Whichever intervals are absent leave their
  next-due field nil, so the derived `due_status` simply ignores that dimension.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> stamp_last_completed(context)
    |> put_next_due_mileage()
    |> put_next_due_date()
  end

  defp stamp_last_completed(%{action: %{name: name}} = changeset, context)
       when name in [:create, :reset] do
    changeset
    |> Ash.Changeset.force_change_attribute(
      :last_completed_mileage,
      current_mileage(changeset, context)
    )
    |> Ash.Changeset.force_change_attribute(:last_completed_date, Date.utc_today())
  end

  defp stamp_last_completed(changeset, _context), do: changeset

  defp put_next_due_mileage(changeset) do
    interval = Ash.Changeset.get_attribute(changeset, :mileage_interval)
    last = Ash.Changeset.get_attribute(changeset, :last_completed_mileage)

    next =
      if interval && last, do: Decimal.add(last, interval), else: nil

    Ash.Changeset.force_change_attribute(changeset, :next_due_mileage, next)
  end

  defp put_next_due_date(changeset) do
    interval = Ash.Changeset.get_attribute(changeset, :time_interval)
    unit = Ash.Changeset.get_attribute(changeset, :time_interval_unit)
    last = Ash.Changeset.get_attribute(changeset, :last_completed_date)

    next =
      if interval && unit && last, do: Date.shift(last, [{unit, interval}]), else: nil

    Ash.Changeset.force_change_attribute(changeset, :next_due_date, next)
  end

  # The vehicle's current odometer, read live when the baseline is (re)stamped. A
  # missing vehicle_id (e.g. an incomplete create) yields nil rather than raising —
  # the `allow_nil? false` on the relationship rejects the changeset cleanly.
  defp current_mileage(changeset, context) do
    case Ash.Changeset.get_argument_or_attribute(changeset, :vehicle_id) do
      nil ->
        nil

      vehicle_id ->
        Fleetms.VehicleManagement.Vehicle
        |> Ash.get!(vehicle_id, tenant: context.tenant, authorize?: false)
        |> Map.get(:mileage)
    end
  end
end
