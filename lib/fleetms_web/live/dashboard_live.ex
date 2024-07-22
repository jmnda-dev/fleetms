defmodule FleetmsWeb.DashboardLive do
  use FleetmsWeb, :live_view

  @stats_period [
    "Last 7 Days": :seven_days,
    "Last 30 Days": :thirty_days,
    "Last 12 Months": :twelve_months
  ]

  require Logger
  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket, :active_link, :dashboard)
      |> assign(:loading_vehicle_dashboard_stats, true)
      |> assign(:loading_inspection_dashboard_stats, true)
      |> assign(:loading_issues_dashboard_stats, true)
      |> assign(:loading_service_reminder_dashboard_stats, true)
      |> assign(:loading_work_order_dashboard_stats, true)
      |> assign(:loading_parts_dashboard_stats, true)
      |> assign(:loading_fuel_dashboard_stats, true)
      |> assign(:period_select_form, %{} |> to_form(as: "stats_period_form"))

    {:ok, socket,
     temporary_assigns: [
       vehicle_dashboard_stats: %{},
       issues_dashboard_stats: %{},
       service_reminder_dashboard_stats: %{},
       work_order_dashboard_stats: %{},
       parts_dashboard_stats: %{}
     ]}
  end

  @impl true
  def handle_event("loadVehiclesStats", _params, socket) do
    tenant = socket.assigns.tenant

    socket =
      start_async(socket, :get_vehicle_dashboard_stats, fn ->
        labels = Fleetms.Enums.vehicle_statuses()

        Fleetms.Dashboard.VehicleStats.get_dashboard_stats(tenant, labels: labels)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("loadInspectionStats", params, socket) do
    tenant = socket.assigns.tenant
    period = get_stats_period_from_params(params)

    socket =
      start_async(socket, :get_inspection_dashboard_stats, fn ->
        Fleetms.Dashboard.InspectionStats.get_dashboard_stats(tenant, period: period)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("loadIssuesStats", _params, socket) do
    tenant = socket.assigns.tenant

    socket =
      start_async(socket, :get_issues_dashboard_stats, fn ->
        labels = Fleetms.Enums.issue_statuses()

        Fleetms.Dashboard.IssueStats.get_dashboard_stats(tenant, labels: labels)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("loadServiceReminderStats", _params, socket) do
    tenant = socket.assigns.tenant

    socket =
      start_async(socket, :get_service_reminder_dashboard_stats, fn ->
        labels = Fleetms.Enums.service_reminder_statuses()
        Fleetms.Dashboard.ServiceReminderStats.get_dashboard_stats(tenant, labels: labels)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("loadWorkOrderStats", _params, socket) do
    tenant = socket.assigns.tenant

    socket =
      start_async(socket, :get_work_order_dashboard_stats, fn ->
        Fleetms.Dashboard.WorkOrderStats.get_dashboard_stats(tenant)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("loadPartsStats", _params, socket) do
    tenant = socket.assigns.tenant

    socket =
      start_async(socket, :get_parts_dashboard_stats, fn ->
        Fleetms.Dashboard.PartsStats.get_dashboard_stats(tenant)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("loadFuelStats", params, socket) do
    tenant = socket.assigns.tenant
    period = get_stats_period_from_params(params)

    socket =
      start_async(socket, :get_fuel_dashboard_stats, fn ->
        Fleetms.Dashboard.FuelStats.get_dashboard_stats(tenant, period: period)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_async(
        :get_vehicle_dashboard_stats,
        {:ok, %Fleetms.Dashboard.VehicleStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :vehicle_dashboard_stats, result)
      |> assign(:loading_vehicle_dashboard_stats, false)

    {:noreply, push_event(socket, "renderVehiclesStats", Map.take(result, [:series, :labels]))}
  end

  @impl true
  def handle_async(
        :get_inspection_dashboard_stats,
        {:ok, %Fleetms.Dashboard.InspectionStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :loading_inspection_dashboard_stats, false)
      |> assign(:total_inspections, result.total)

    {:noreply, push_event(socket, "renderInspectionStats", result)}
  end

  @impl true
  def handle_async(
        :get_issues_dashboard_stats,
        {:ok, %Fleetms.Dashboard.IssueStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :issues_dashboard_stats, result)
      |> assign(:loading_issues_dashboard_stats, false)

    {:noreply, socket}
  end

  @impl true
  def handle_async(
        :get_service_reminder_dashboard_stats,
        {:ok, %Fleetms.Dashboard.ServiceReminderStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :service_reminder_dashboard_stats, result)
      |> assign(:loading_service_reminder_dashboard_stats, false)

    {:noreply,
     push_event(socket, "renderServiceRemindersStats", Map.take(result, [:series, :labels]))}
  end

  @impl true
  def handle_async(
        :get_work_order_dashboard_stats,
        {:ok, %Fleetms.Dashboard.WorkOrderStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :work_order_dashboard_stats, result)
      |> assign(:loading_work_order_dashboard_stats, false)

    {:noreply, socket}
  end

  @impl true
  def handle_async(
        :get_parts_dashboard_stats,
        {:ok, %Fleetms.Dashboard.PartsStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :parts_dashboard_stats, result)
      |> assign(:loading_parts_dashboard_stats, false)

    {:noreply, socket}
  end

  @impl true
  def handle_async(
        :get_fuel_dashboard_stats,
        {:ok, %Fleetms.Dashboard.FuelStats{} = result},
        socket
      ) do
    socket =
      assign(socket, :loading_fuel_dashboard_stats, false)

    chart_horizontal_orientation =
      if result.period not in [:seven_days, :twelve_months], do: true, else: false

    data =
      Map.take(result, [:series, :categories])
      |> Map.merge(%{horizontal: chart_horizontal_orientation})

    {:noreply, push_event(socket, "renderFuelStats", data)}
  end

  @impl true
  def handle_async(handle_async_name, {:error, result}, socket) do
    Logger.warning("""
    Something went wrong while retrieving the async result.
    Handle Async Name: #{inspect(handle_async_name)}
    Error Result: #{inspect(result)}
    """)

    {:noreply, socket}
  end

  defp get_stats_period_from_params(params) do
    case params do
      %{"stats_period_form" => %{"period" => "seven_days"}} -> :seven_days
      %{"stats_period_form" => %{"period" => "thirty_days"}} -> :thirty_days
      %{"stats_period_form" => %{"period" => "twelve_months"}} -> :twelve_months
      _params -> :seven_days
    end
  end

  defp get_inspection_stats_period_options, do: @stats_period
  defp get_fuel_stats_period_options, do: @stats_period
end
