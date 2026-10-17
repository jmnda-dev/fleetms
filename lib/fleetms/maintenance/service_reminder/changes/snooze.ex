defmodule Fleetms.Maintenance.ServiceReminder.Changes.Snooze do
  @moduledoc """
  Postpones a reminder's due date by the action's `days` argument.

  Snoozing only defers the **date** side of a reminder (its mileage due, if any,
  is left untouched), so it's rejected on a reminder that has no `next_due_date`.
  The new date is measured from whichever is later — today or the existing due
  date — so snoozing an already-overdue reminder still pushes it into the future.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    days = Ash.Changeset.get_argument(changeset, :days)
    current = Ash.Changeset.get_attribute(changeset, :next_due_date)

    if is_nil(current) do
      Ash.Changeset.add_error(changeset,
        field: :next_due_date,
        message: "This reminder isn't date-based, so it can't be snoozed."
      )
    else
      today = Date.utc_today()
      base = if Date.compare(current, today) == :gt, do: current, else: today
      Ash.Changeset.force_change_attribute(changeset, :next_due_date, Date.add(base, days))
    end
  end
end
