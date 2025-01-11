defmodule Fleetms.Dashboard.WorkOrderStats do
  defstruct total: 0, open: 0, completed: 0

  def get_dashboard_stats(tenant) do
    {:ok, %{total: total, open: open, completed: completed}} =
      Fleetms.VehicleMaintenance.WorkOrder.get_dashboard_stats(tenant)

    %__MODULE__{
      total: total,
      open: open,
      completed: completed
    }
  end
end
