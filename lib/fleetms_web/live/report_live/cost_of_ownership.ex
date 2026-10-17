defmodule FleetmsWeb.ReportLive.CostOfOwnership do
  @moduledoc """
  Cost of ownership report: per-vehicle maintenance + fuel spend over a period, with the
  distance covered and cost per distance-unit, worst first. Filters live in the URL so
  the CSV export link and a refresh carry them. Distance is approximated from fuel-log
  odometer readings (see `Fleetms.Reports.cost_of_ownership_report/2`).
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Reports
  alias Fleetms.VehicleManagement

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Cost of ownership"), active_link: :reports)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope
    report = Reports.cost_of_ownership_report(scope, params)

    {:noreply,
     socket
     |> assign(:report, report)
     |> assign(:filters, report.filters)
     |> assign(:vehicles, vehicle_options(scope))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      organizations={@organizations}
      unread_notifications_count={@unread_notifications_count}
      recent_notifications={@recent_notifications}
      notifications_open={@notifications_open}
    >
      <.breadcrumbs items={[
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Reports"), path: ~p"/o/#{org(assigns)}/reports"},
        %{label: gettext("Cost of ownership")}
      ]} />

      <.header>
        {gettext("Cost of ownership")}
        <:subtitle>
          {gettext("What each vehicle costs to run — maintenance, fuel and expenses.")}
        </:subtitle>
        <:actions>
          <.button variant="secondary" phx-hook="PrintButton" id="print-report">
            <.icon name="fa-print" class="me-2" /> {gettext("Print / PDF")}
          </.button>
          <.button navigate={export_path(assigns)}>
            <.icon name="fa-file-csv" class="me-2" /> {gettext("Export CSV")}
          </.button>
        </:actions>
      </.header>

      <form phx-change="filter" class="no-print mt-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <.date_input id="from" name="from" value={to_string(@filters.from)} label={gettext("From")} />
        <.date_input id="to" name="to" value={to_string(@filters.to)} label={gettext("To")} />
        <.input
          type="select"
          name="vehicle_id"
          value={@filters.vehicle_id || ""}
          label={gettext("Vehicle")}
          prompt={gettext("All vehicles")}
          options={@vehicles}
        />
      </form>

      <div id="report" class="mt-4">
        <div class="hidden print-only mb-4">
          <h1 class="text-lg font-bold">{gettext("Cost of ownership")}</h1>
          <p class="text-sm">
            {Format.date(@filters.from, org(assigns))} — {Format.date(@filters.to, org(assigns))}
          </p>
        </div>

        <div class="grid grid-cols-2 gap-3 lg:grid-cols-5">
          <.summary label={gettext("Vehicles")} value={@report.summary.count} />
          <.summary
            label={gettext("Maintenance")}
            value={money(@report.summary.maintenance, @report.currency)}
          />
          <.summary label={gettext("Fuel")} value={money(@report.summary.fuel, @report.currency)} />
          <.summary
            label={gettext("Expenses")}
            value={money(@report.summary.expenses, @report.currency)}
          />
          <.summary
            label={gettext("Total spend")}
            value={money(@report.summary.total, @report.currency)}
            strong
          />
        </div>

        <div
          tabindex="0"
          role="region"
          aria-label="Cost of ownership table"
          class="mt-4 overflow-x-auto rounded-base border border-default bg-white shadow-sm dark:bg-gray-800"
        >
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Maintenance")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Fuel")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Expenses")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Total")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Distance")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  {gettext("Cost / %{unit}", unit: Format.distance_unit(org(assigns)))}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={row <- @report.rows}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <td class="whitespace-nowrap px-4 py-3 font-medium text-heading">
                  <.link
                    navigate={~p"/o/#{org(assigns)}/vehicles/#{row.id}"}
                    class="hover:underline"
                  >
                    {row.vehicle}
                  </.link>
                </td>
                <td class="px-4 py-3 text-right">{money(row.maintenance, @report.currency)}</td>
                <td class="px-4 py-3 text-right">{money(row.fuel, @report.currency)}</td>
                <td class="px-4 py-3 text-right">{money(row.expenses, @report.currency)}</td>
                <td class="px-4 py-3 text-right font-medium text-heading">
                  {money(row.total, @report.currency)}
                </td>
                <td class="px-4 py-3 text-right">{Format.distance(row.distance, org(assigns))}</td>
                <td class="px-4 py-3 text-right">
                  {cost_per_distance(row.total, row.distance, assigns)}
                </td>
              </tr>
              <tr :if={@report.rows == []}>
                <td colspan="7" class="px-4 py-10 text-center text-body">
                  {gettext("No vehicle activity in this range.")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>

    <style>
      .print-only { display: none; }
      @media print {
        body * { visibility: hidden; }
        #report, #report * { visibility: visible; }
        #report { position: absolute; inset: 0; }
        .no-print { display: none !important; }
        .print-only { display: block !important; }
      }
    </style>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :strong, :boolean, default: false

  defp summary(assigns) do
    ~H"""
    <div class="rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800">
      <p class="text-xs font-medium text-body">{@label}</p>
      <p class={["mt-1 font-bold text-heading", (@strong && "text-2xl") || "text-xl"]}>{@value}</p>
    </div>
    """
  end

  @impl true
  def handle_event("filter", params, socket) do
    query =
      %{"from" => params["from"], "to" => params["to"], "vehicle_id" => params["vehicle_id"]}
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/o/#{org(socket)}/reports/cost-of-ownership?#{query}")}
  end

  defp export_path(assigns) do
    f = assigns.filters

    query =
      %{"from" => to_string(f.from), "to" => to_string(f.to), "vehicle_id" => f.vehicle_id}
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    ~p"/o/#{org(assigns)}/reports/cost-of-ownership.csv?#{query}"
  end

  # Cost per distance-unit in the org's unit; blank when distance is unknown or zero.
  defp cost_per_distance(total, distance_km, assigns) do
    org = org(assigns)

    case Format.distance_value(distance_km, org) do
      %Decimal{} = distance ->
        if Decimal.compare(distance, Decimal.new(0)) == :gt do
          per = Decimal.div(total, distance)
          "#{assigns.report.currency} #{Format.number(per)}"
        else
          "—"
        end

      _ ->
        "—"
    end
  end

  defp vehicle_options(scope) do
    VehicleManagement.list_vehicles!(%{}, scope: scope, page: [limit: 500])
    |> Map.get(:results)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp money(%Decimal{} = amount, currency), do: "#{currency} #{Format.number(amount)}"

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
