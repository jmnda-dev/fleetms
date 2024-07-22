defmodule Fleetms.Dashboard.VehicleStats do
  defstruct total: 0, active: 0, under_maintenance: 0, out_of_service: 0, series: [], labels: []

  def get_dashboard_stats(tenant, opts \\ []) do
    %{
      active: active,
      total: total,
      under_maintenance: under_maintenance,
      out_of_service: out_of_service
    } = Fleetms.Vehicles.Vehicle.get_dashboard_stats!(tenant)

    series = [active, under_maintenance, out_of_service]

    %__MODULE__{
      labels: opts[:labels] || [],
      active: active,
      total: total,
      under_maintenance: under_maintenance,
      out_of_service: out_of_service,
      series: series
    }
  end
end
