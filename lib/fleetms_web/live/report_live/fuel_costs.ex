defmodule FleetmsWeb.ReportLive.FuelCosts do
  use FleetmsWeb, :live_view

  alias Fleetms.Dashboard

  @stats_period [
    "Last 7 Days": :seven_days,
    "Last 30 Days": :thirty_days,
    "Last 12 Months": :twelve_months
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket, :active_link, :reports)
      |> assign(:period_select_form, %{} |> to_form(as: "stats_period_form"))

    {:ok, socket}
  end

  @impl true
  def handle_event("loadFuelCostOverTimeStats", params, socket) do
    tenant = socket.assigns.tenant
    period = get_stats_period_from_params(params)

    socket =
      start_async(socket, :get_fuel_dashboard_stats, fn ->
        Dashboard.FuelStats.get_dashboard_stats(tenant, period: period)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_async(
        :get_fuel_dashboard_stats,
        {:ok, %Dashboard.FuelStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :loading_fuel_dashboard_stats, false)

    chart_horizontal_orientation =
      if result.period not in [:seven_days, :twelve_months], do: true, else: false

    data =
      Map.take(result, [:series, :categories])
      |> Map.merge(%{horizontal: chart_horizontal_orientation})

    {:noreply, push_event(socket, "renderFuelCostOverTimeStats", data)}
  end

  defp get_stats_period_from_params(params) do
    case params do
      %{"stats_period_form" => %{"period" => "seven_days"}} -> :seven_days
      %{"stats_period_form" => %{"period" => "thirty_days"}} -> :thirty_days
      %{"stats_period_form" => %{"period" => "twelve_months"}} -> :twelve_months
      _params -> :seven_days
    end
  end

  defp get_fuel_stats_period_options, do: @stats_period
end
