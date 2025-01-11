defmodule Fleetms.Dashboard.ServiceReminderStats do
  defstruct upcoming: 0,
            due_soon: 0,
            overdue: 0,
            series: [],
            labels: [],
            due_soon_service_task_count: [],
            overdue_service_task_count: []

  def get_dashboard_stats(tenant, opts \\ []) do
    %{
      status_counts: status_counts,
      due_soon_service_task_count: due_soon_service_task_count,
      overdue_service_task_count: overdue_service_task_count
    } =
      Fleetms.VehicleMaintenance.ServiceReminder.get_dashboard_stats!(tenant)

    %{
      upcoming: upcoming,
      due_soon: due_soon,
      overdue: overdue
    } = status_counts

    series = [upcoming, due_soon, overdue]

    %__MODULE__{
      labels: opts[:labels] || [],
      upcoming: upcoming,
      due_soon: due_soon,
      overdue: overdue,
      series: series,
      due_soon_service_task_count: due_soon_service_task_count,
      overdue_service_task_count: overdue_service_task_count
    }
  end
end
