defmodule Fleetms.Service.ServiceReminder.Changes.SetStatus do
  @moduledoc """
  Sets the reminder status, based on the value of `next_due_mileage`, `vehicle_mileage` and `mileage_threshold`.
  As for setting the status based on the `time_interval`, `time_threshold` and `next_due_date`, those will be
  done when the `mileage_interval` or `time_interval` changes, the reminder is reset or by background scheduled jobs e.g Oban jos
  """
  use Ash.Resource.Change

  @status_priority [nil: 0, Upcoming: 1, "Due Soon": 2, Overdue: 3]

  @doc """
  Sets the service reminder status base on the mileage or time passed. The calculate_statusd/1 function
  calculates the status to set on the reminder. It takes into account the principle of `whichever comes first`.
  Using the `@status_priority`, and the value returned by `derive_status_from_time_interval/1` and `derive_status_from_mileage_interval/1`.
  we can determing which comes first, either the status derived from the `mileage` or `time`.
  """
  def change(%{action: action} = changeset, _opts, _context) do
    changing_attributes =
      [
        Ash.Changeset.changing_attribute?(changeset, :mileage_interval),
        Ash.Changeset.changing_attribute?(changeset, :mileage_threshold),
        Ash.Changeset.changing_attribute?(changeset, :time_interval),
        Ash.Changeset.changing_attribute?(changeset, :time_interval_unit),
        Ash.Changeset.changing_attribute?(changeset, :time_threshold),
        Ash.Changeset.changing_attribute?(changeset, :time_threshold_unit)
      ]

    allowed_actions = [
      :create,
      :update_from_vehicle,
      :update_by_work_order_completion,
      :update_from_service_group_schedule,
      :update_by_work_order_reopen
    ]

    if action.name in allowed_actions or Enum.any?(changing_attributes) do
      status = calculate_status(changeset)

      Ash.Changeset.force_change_attribute(changeset, :due_status, status)
    else
      changeset
    end
  end

  defp calculate_status(changeset) do
    status_from_mileage = derive_status_from_mileage(changeset)
    status_from_time = derive_status_from_time(changeset)

    mileage_priority_value = Keyword.get(@status_priority, status_from_mileage)
    time_priority_value = Keyword.get(@status_priority, status_from_time)

    cond do
      mileage_priority_value >= time_priority_value ->
        status_from_mileage

      time_priority_value >= mileage_priority_value ->
        status_from_time
    end
  end

  defp derive_status_from_mileage(changeset) do
    next_due_mileage = Ash.Changeset.get_attribute(changeset, :next_due_mileage)

    # If the next_due_mileage is nil, it means the mileage interval is also nil so we can't derive the status of the reminder from mileage
    if is_nil(next_due_mileage) do
      nil
    else
      vehicle_mileage = get_vehicle_mileage(changeset)
      mileage_threshold = Ash.Changeset.get_attribute(changeset, :mileage_threshold) || 0
      mileage_threshold_diff = Decimal.sub(next_due_mileage, mileage_threshold)

      cond do
        Decimal.compare(vehicle_mileage, next_due_mileage) == :gt ->
          :Overdue

        Decimal.compare(vehicle_mileage, next_due_mileage) == :eq ->
          :Overdue

        (Decimal.compare(vehicle_mileage, mileage_threshold_diff) == :gt or
           Decimal.compare(vehicle_mileage, mileage_threshold_diff) == :eq) and
            Decimal.compare(vehicle_mileage, next_due_mileage) == :lt ->
          :"Due Soon"

        Decimal.compare(vehicle_mileage, mileage_threshold_diff) == :lt ->
          :Upcoming
      end
    end
  end

  defp derive_status_from_time(changeset) do
    next_due_date = Ash.Changeset.get_attribute(changeset, :next_due_date)

    # If the next_due_date is nil, it means the time interval is also nil so we can't derive the status of the reminder from time interval
    if is_nil(next_due_date) do
      nil
    else
      time_threshold = Ash.Changeset.get_attribute(changeset, :time_threshold) || 0

      time_threshold_unit =
        Ash.Changeset.get_attribute(changeset, :time_threshold_unit) || :"Week(s)"

      threshold_date_shift_unit =
        Fleetms.Utils.parse_reminder_time_interval_shift_unit(time_threshold_unit)

      time_threshold_diff =
        Timex.shift(next_due_date, [{threshold_date_shift_unit, -time_threshold}])

      todays_date = Date.utc_today()

      cond do
        Date.compare(todays_date, next_due_date) == :gt ->
          :Overdue

        Date.compare(todays_date, next_due_date) == :eq ->
          :Overdue

        Date.compare(todays_date, time_threshold_diff) == :gt and
            Date.compare(todays_date, next_due_date) == :lt ->
          :"Due Soon"

        Date.compare(todays_date, time_threshold_diff) == :lt ->
          :Upcoming
      end
    end
  end

  defp get_vehicle_mileage(changeset) do
    case changeset.action.name do
      :update_from_vehicle ->
        Ash.Changeset.get_argument(changeset, :vehicle_mileage)

      action when action in [:create, :update_from_service_group_schedule] ->
        changeset
        |> Ash.Changeset.get_argument_or_attribute(:vehicle_id)
        |> Fleetms.Vehicles.Vehicle.get_by_id!(tenant: changeset.tenant)
        |> Map.get(:mileage)

      _action ->
        Ash.Changeset.get_data(changeset, :vehicle_mileage)
    end
  end
end
