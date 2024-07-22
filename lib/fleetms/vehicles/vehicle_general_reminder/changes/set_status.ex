defmodule Fleetms.Vehicles.VehicleGeneralReminder.Changes.SetStatus do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    now = Date.utc_today()
    due_date_threshold = Ash.Changeset.get_attribute(changeset, :due_date_threshold)
    due_date_threshold_unit = Ash.Changeset.get_attribute(changeset, :due_date_threshold_unit)

    due_date = Ash.Changeset.get_attribute(changeset, :due_date)

    cond do
      not is_nil(due_date) and Date.compare(now, due_date) in [:gt, :eq] ->
        Ash.Changeset.force_change_attribute(changeset, :due_status, :Overdue)

      not is_nil(due_date_threshold) and not is_nil(due_date_threshold_unit) ->
        date_shift_unit =
          Fleetms.Utils.parse_reminder_time_interval_shift_unit(due_date_threshold_unit)

        date_diff = Timex.shift(due_date, [{date_shift_unit, -due_date_threshold}])

        if Date.compare(now, date_diff) == :gt and Date.compare(now, due_date) == :lt do
          Ash.Changeset.force_change_attribute(changeset, :due_status, :"Due Soon")
        else
          Ash.Changeset.force_change_attribute(changeset, :due_status, :Upcoming)
        end

      true ->
        Ash.Changeset.force_change_attribute(changeset, :due_status, :Upcoming)
    end
  end
end
