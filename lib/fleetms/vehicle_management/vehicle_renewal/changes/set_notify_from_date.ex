defmodule Fleetms.VehicleManagement.VehicleRenewal.Changes.SetNotifyFromDate do
  @moduledoc """
  Computes and stores `notify_from_date` — the date on which a renewal starts
  reading as "Due Soon" — from `due_date` shifted back by the `notify_before` lead
  time, using exact calendar math (`Date.shift/2` handles month/year lengths).

  Storing this date (rather than recomputing a status on a schedule) is what lets
  the `status` calculation be a pure, always-correct date comparison in the
  database: nothing has to run as time passes. It's recomputed here whenever the
  due date or lead time changes. With no lead time set, it's cleared (and the
  renewal simply reads "Upcoming" until it's due).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    due_date = Ash.Changeset.get_attribute(changeset, :due_date)
    amount = Ash.Changeset.get_attribute(changeset, :notify_before)
    unit = Ash.Changeset.get_attribute(changeset, :notify_before_unit)

    notify_from =
      if due_date && amount && unit do
        Date.shift(due_date, duration(unit, -amount))
      end

    Ash.Changeset.force_change_attribute(changeset, :notify_from_date, notify_from)
  end

  defp duration(:days, n), do: [day: n]
  defp duration(:weeks, n), do: [week: n]
  defp duration(:months, n), do: [month: n]
  defp duration(:years, n), do: [year: n]
end
