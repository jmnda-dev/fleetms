defmodule Fleetms.Service.WorkOrder.Changes.RestoreServiceReminders do
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    work_order_id = Ash.Changeset.get_data(changeset, :id)
    vehicle_id = Ash.Changeset.get_data(changeset, :vehicle_id)

    service_reminder_histories =
      Fleetms.Service.ServiceReminderHistory
      |> Ash.Query.filter(
        work_order_id == ^work_order_id and not is_nil(service_reminder_id) and
          service_reminder.vehicle_id == ^vehicle_id
      )
      |> Ash.Query.load(service_reminder: [:vehicle_mileage])
      |> Ash.Query.set_tenant(changeset.tenant)
      |> Ash.read!()

    changeset
    |> Ash.Changeset.after_action(fn _changeset, updated_work_order ->
      Enum.map(service_reminder_histories, fn %{service_reminder: service_reminder} =
                                                service_reminder_history ->
        service_reminder_params = build_service_reminder_params(service_reminder_history)

        service_reminder
        |> Ash.Changeset.for_update(:update_by_work_order_reopen, service_reminder_params)
        |> Ash.update!()
      end)

      {:ok, updated_work_order}
    end)
  end

  defp build_service_reminder_params(service_reminder_history) do
    # create a map of the service reminder attributes to be restored
    Map.take(service_reminder_history, [
      :last_completed_mileage,
      :last_completed_hours,
      :last_completed_date
    ])
    |> Map.put(:id, service_reminder_history.service_reminder_id)
  end
end
