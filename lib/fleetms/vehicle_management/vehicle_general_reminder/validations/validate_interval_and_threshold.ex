defmodule Fleetms.VehicleManagement.VehicleGeneralReminder.Validations.ValidateIntervalAndThreshold do
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    time_interval = Ash.Changeset.get_attribute(changeset, :time_interval)
    time_interval_unit = Ash.Changeset.get_attribute(changeset, :time_interval_unit)
    due_date_threshold = Ash.Changeset.get_attribute(changeset, :due_date_threshold)
    due_date_threshold_unit = Ash.Changeset.get_attribute(changeset, :due_date_threshold_unit)

    cond do
      not is_nil(time_interval) and is_nil(time_interval_unit) ->
        {:error,
         field: :time_interval_unit, message: "Can not be blank if the Time Interval is specified"}

      is_nil(time_interval) and not is_nil(time_interval_unit) ->
        {:error,
         field: :time_interval, message: "Can not be blank if the Time Interval Unit is specified"}

      not is_nil(due_date_threshold) and is_nil(due_date_threshold_unit) ->
        {:error,
         field: :due_date_threshold_unit,
         message: "Can not be blank if the Due Date Threshold is specified"}

      is_nil(due_date_threshold) and not is_nil(due_date_threshold_unit) ->
        {:error,
         field: :due_date_threshold,
         message: "Can not be blank if the Due Date Threshold Unit is specified"}

      true ->
        :ok
    end
  end
end
