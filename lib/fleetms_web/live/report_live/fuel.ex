defmodule FleetmsWeb.ReportLive.Fuel do
  @moduledoc """
  Fuel & economy report: fuel entries in a period with each fill's economy (from the
  distance since the vehicle's previous fill), plus totals. Filters live in the URL;
  exports to CSV and prints. Economy renders in the org's unit (L/100km or mpg).
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Reports
  alias Fleetms.VehicleManagement

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Fuel & economy"), active_link: :reports)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope
    report = Reports.fuel_report(scope, params)

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
        %{label: gettext("Fuel & economy")}
      ]} />

      <.header>
        {gettext("Fuel & economy")}
        <:subtitle>{gettext("Every fill-up, what it cost, and the economy it delivered.")}</:subtitle>
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
          <h1 class="text-lg font-bold">{gettext("Fuel & economy")}</h1>
          <p class="text-sm">
            {Format.date(@filters.from, org(assigns))} — {Format.date(@filters.to, org(assigns))}
          </p>
        </div>

        <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <.summary label={gettext("Fill-ups")} value={@report.summary.count} />
          <.summary
            label={gettext("Fuel")}
            value={Format.volume(@report.summary.quantity, org(assigns))}
          />
          <.summary
            label={gettext("Total cost")}
            value={money(@report.summary.cost, @report.currency)}
          />
          <.summary
            label={gettext("Avg economy")}
            value={Format.fuel_economy(@report.summary.distance, @report.summary.fuel, org(assigns))}
            strong
          />
        </div>

        <div
          tabindex="0"
          role="region"
          aria-label="Fuel report table"
          class="mt-4 overflow-x-auto rounded-base border border-default bg-white shadow-sm dark:bg-gray-800"
        >
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Date")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Quantity")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Cost")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Odometer")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Economy")}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={row <- @report.rows}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <td class="whitespace-nowrap px-4 py-3">{Format.date(row.date, org(assigns))}</td>
                <td class="px-4 py-3">{row.vehicle}</td>
                <td class="px-4 py-3 text-right">{Format.volume(row.quantity, org(assigns))}</td>
                <td class="px-4 py-3 text-right">{Format.money(row.cost)}</td>
                <td class="px-4 py-3 text-right">{Format.distance(row.odometer, org(assigns))}</td>
                <td class="px-4 py-3 text-right">{economy(row.economy, assigns)}</td>
              </tr>
              <tr :if={@report.rows == []}>
                <td colspan="6" class="px-4 py-10 text-center text-body">
                  {gettext("No fuel logged in this range.")}
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

    {:noreply, push_patch(socket, to: ~p"/o/#{org(socket)}/reports/fuel?#{query}")}
  end

  defp export_path(assigns) do
    f = assigns.filters

    query =
      %{"from" => to_string(f.from), "to" => to_string(f.to), "vehicle_id" => f.vehicle_id}
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    ~p"/o/#{org(assigns)}/reports/fuel.csv?#{query}"
  end

  defp economy(nil, _assigns), do: "—"
  defp economy(%{distance_km: d, fuel_l: f}, assigns), do: Format.fuel_economy(d, f, org(assigns))

  defp vehicle_options(scope) do
    VehicleManagement.list_vehicles!(%{}, scope: scope, page: [limit: 500])
    |> Map.get(:results)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp money(%Decimal{} = amount, currency), do: "#{currency} #{Format.number(amount)}"

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
