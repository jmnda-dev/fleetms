defmodule Fleetms.VehicleManagement.Workers.UpdateVehicleGeneralReminderStatuses do
  use Oban.Worker, queue: :vehicle_general_reminders, max_attempts: 3
  alias Fleetms.{Accounts, VehicleManagement}
  alias VehicleManagement.VehicleGeneralReminder

  def perform(_job) do
    tenants = Accounts.get_all_tenants!()

    due_soon_query = VehicleGeneralReminder.build_due_soon_reminders_query!()
    overdue_query = VehicleGeneralReminder.build_overdue_reminders_query!()

    Enum.map(tenants, fn tenant ->
      due_soon_query
      |> Ash.bulk_update(:bulk_update_status, %{due_status: :"Due Soon"},
        tenant: tenant,
        return_errors?: true
      )

      overdue_query
      |> Ash.bulk_update(:bulk_update_status, %{due_status: :Overdue},
        tenant: tenant,
        return_errors?: true
      )
    end)

    :ok
  end
end
