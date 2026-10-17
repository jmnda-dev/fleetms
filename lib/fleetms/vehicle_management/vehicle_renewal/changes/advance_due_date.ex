defmodule Fleetms.VehicleManagement.VehicleRenewal.Changes.AdvanceDueDate do
  @moduledoc """
  Rolls a recurring renewal forward one cycle: advances `due_date` by the
  recurrence interval (from the existing due date, so it stays on its anniversary)
  and stamps `last_completed_date` with today. Only meaningful when a recurrence is
  set — the `mark_renewed` action validates that.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    due_date = Ash.Changeset.get_attribute(changeset, :due_date)
    amount = Ash.Changeset.get_attribute(changeset, :recurrence_interval)
    unit = Ash.Changeset.get_attribute(changeset, :recurrence_unit)

    if due_date && amount && unit do
      changeset
      |> Ash.Changeset.force_change_attribute(
        :due_date,
        Date.shift(due_date, duration(unit, amount))
      )
      |> Ash.Changeset.force_change_attribute(:last_completed_date, Date.utc_today())
    else
      changeset
    end
  end

  defp duration(:days, n), do: [day: n]
  defp duration(:weeks, n), do: [week: n]
  defp duration(:months, n), do: [month: n]
  defp duration(:years, n), do: [year: n]
end
