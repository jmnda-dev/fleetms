defmodule Fleetms.Service.ServiceReminder.Changes.SetNextDue do
  use Ash.Resource.Change

  def change(changeset, _opts, %Ash.Resource.Change.Context{tenant: tenant}) do
    mileage_is_changing = Ash.Changeset.changing_attribute?(changeset, :mileage_interval)
    time_interval_changing = Ash.Changeset.changing_attribute?(changeset, :time_interval)

    changeset
    |> Ash.Changeset.set_tenant(tenant)
    |> update_last_completed()
    |> update_mileage_next_due(mileage_is_changing)
    |> update_time_interval_next_due_date(time_interval_changing)
  end

  defp update_mileage_next_due(
         %{action: action} = changeset,
         false
       )
       when action.name in [:update_by_work_order_completion, :update_by_work_order_reopen] do
    update_mileage_next_due(changeset, true)
  end

  defp update_mileage_next_due(changeset, false),
    do: changeset

  defp update_mileage_next_due(changeset, true) do
    mileage_interval = Ash.Changeset.get_attribute(changeset, :mileage_interval)

    if is_nil(mileage_interval) do
      changeset
    else
      last_completed_mileage = Ash.Changeset.get_attribute(changeset, :last_completed_mileage)

      changeset
      |> Ash.Changeset.force_change_attribute(
        :next_due_mileage,
        Decimal.add(last_completed_mileage, mileage_interval)
      )
    end
  end

  defp update_time_interval_next_due_date(
         %{action: action} = changeset,
         false
       )
       when action.name in [:update_by_work_order_completion, :update_by_work_order_reopen] do
    update_time_interval_next_due_date(changeset, true)
  end

  defp update_time_interval_next_due_date(changeset, false),
    do: changeset

  defp update_time_interval_next_due_date(changeset, true) do
    time_interval = Ash.Changeset.get_attribute(changeset, :time_interval)

    if is_nil(time_interval) do
      changeset
    else
      time_interval_unit = Ash.Changeset.get_attribute(changeset, :time_interval_unit)
      last_completed_date = Ash.Changeset.get_attribute(changeset, :last_completed_date)

      date_shift_unit =
        Fleetms.Utils.parse_reminder_time_interval_shift_unit(time_interval_unit)

      changeset
      |> Ash.Changeset.force_change_attribute(
        :next_due_date,
        Timex.shift(last_completed_date, [{date_shift_unit, time_interval}])
      )
    end
  end

  defp update_last_completed(changeset) do
    case changeset.action.name do
      :create ->
        current_vehicle_mileage = get_vehicle_mileage(changeset)

        changeset
        |> Ash.Changeset.force_change_attribute(:last_completed_mileage, current_vehicle_mileage)
        |> Ash.Changeset.force_change_attribute(:last_completed_date, Date.utc_today())

      :update_by_work_order_completion ->
        vehicle_mileage = Ash.Changeset.get_data(changeset, :vehicle_mileage)

        changeset
        |> Ash.Changeset.force_change_attribute(:last_completed_mileage, vehicle_mileage)
        # Here I set last_completed_date to today, because the work order was completed today and to calculate
        # the next_due_date, we calculate it from the last_completed_date, which is today.
        |> Ash.Changeset.force_change_attribute(:last_completed_date, Date.utc_today())

      :update_by_work_order_reopen ->
        last_completed_mileage = Ash.Changeset.get_argument(changeset, :last_completed_mileage)
        last_completed_date = Ash.Changeset.get_argument(changeset, :last_completed_date)
        last_completed_hours = Ash.Changeset.get_argument(changeset, :last_completed_hours)

        changeset
        |> Ash.Changeset.force_change_attribute(:last_completed_mileage, last_completed_mileage)
        |> Ash.Changeset.force_change_attribute(:last_completed_date, last_completed_date)
        |> Ash.Changeset.force_change_attribute(:last_completed_hours, last_completed_hours)

      _other ->
        changeset
    end
  end

  defp get_vehicle_mileage(changeset) do
    if changeset.action.name == :create do
      # TODO: Make optimizations so that the query is only performed once and used in the SetNextDue and SetStatus
      # changes, perhaps this can be set as an argument before an action is run.
      changeset
      |> Ash.Changeset.get_argument_or_attribute(:vehicle_id)
      |> Fleetms.Vehicles.Vehicle.get_by_id!(tenant: changeset.tenant)
      |> Map.get(:mileage)
    else
      Ash.Changeset.get_data(changeset, :vehicle_mileage)
    end
  end
end
