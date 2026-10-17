defmodule FleetmsWeb.ReportLive.Maintenance do
  @moduledoc """
  Maintenance & cost history report: work orders in a date range (optionally by vehicle
  and status) with their parts/labour/total cost and a summary. Filters live in the URL
  so the "Export CSV" link and a browser refresh carry them; the CSV is served by
  `ReportController`. A print-optimized layout backs "Save as PDF".
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Reports
  alias Fleetms.VehicleManagement

  @statuses [
    {"All statuses", ""},
    {"Open", "open"},
    {"In progress", "in_progress"},
    {"Completed", "completed"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Maintenance report"), active_link: :reports)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope
    report = Reports.maintenance_report(scope, params)

    {:noreply,
     socket
     |> assign(:report, report)
     |> assign(:filters, report.filters)
     |> assign(:vehicles, vehicle_options(scope))
     |> assign(:statuses, @statuses)}
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
        %{label: gettext("Maintenance")}
      ]} />

      <.header>
        {gettext("Maintenance & cost history")}
        <:subtitle>{gettext("Work orders, their tasks and what they cost.")}</:subtitle>
        <:actions>
          <.button variant="secondary" phx-hook="PrintButton" id="print-report">
            <.icon name="fa-print" class="me-2" /> {gettext("Print / PDF")}
          </.button>
          <.button navigate={export_path(assigns)}>
            <.icon name="fa-file-csv" class="me-2" /> {gettext("Export CSV")}
          </.button>
        </:actions>
      </.header>

      <form phx-change="filter" class="no-print mt-6 grid grid-cols-1 gap-3 sm:grid-cols-4">
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
        <.input
          type="select"
          name="status"
          value={to_string(@filters.status || "")}
          label={gettext("Status")}
          options={@statuses}
        />
      </form>

      <div id="report" class="mt-4">
        <div class="hidden print-only mb-4">
          <h1 class="text-lg font-bold">{gettext("Maintenance & cost history")}</h1>
          <p class="text-sm">
            {Format.date(@filters.from, org(assigns))} — {Format.date(@filters.to, org(assigns))}
          </p>
        </div>

        <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <.summary label={gettext("Work orders")} value={@report.summary.count} />
          <.summary
            label={gettext("Parts")}
            value={money(@report.summary.parts, @report.currency)}
          />
          <.summary
            label={gettext("Labour")}
            value={money(@report.summary.labour, @report.currency)}
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
          aria-label="Maintenance report table"
          class="mt-4 overflow-x-auto rounded-base border border-default bg-white shadow-sm dark:bg-gray-800"
        >
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("#")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Issued")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Tasks")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Parts")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Labour")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Total")}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={row <- @report.rows}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <td class="whitespace-nowrap px-4 py-3 font-medium text-heading">
                  <.link
                    navigate={~p"/o/#{org(assigns)}/work-orders/#{row.id}"}
                    class="hover:underline"
                  >
                    #{row.number}
                  </.link>
                </td>
                <td class="px-4 py-3">{row.vehicle}</td>
                <td class="whitespace-nowrap px-4 py-3">
                  {Format.date(row.issued_at, org(assigns))}
                </td>
                <td class="px-4 py-3">{humanize(row.status)}</td>
                <td class="px-4 py-3 text-right">{row.task_count}</td>
                <td class="px-4 py-3 text-right">{money(row.parts, @report.currency)}</td>
                <td class="px-4 py-3 text-right">{money(row.labour, @report.currency)}</td>
                <td class="px-4 py-3 text-right font-medium text-heading">
                  {money(row.total, @report.currency)}
                </td>
              </tr>
              <tr :if={@report.rows == []}>
                <td colspan="8" class="px-4 py-10 text-center text-body">
                  {gettext("No work orders in this range.")}
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
      %{
        "from" => params["from"],
        "to" => params["to"],
        "vehicle_id" => params["vehicle_id"],
        "status" => params["status"]
      }
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/o/#{org(socket)}/reports/maintenance?#{query}")}
  end

  # The CSV route mirrors the current filters so the download matches what's on screen.
  defp export_path(assigns) do
    f = assigns.filters

    query =
      %{
        "from" => to_string(f.from),
        "to" => to_string(f.to),
        "vehicle_id" => f.vehicle_id,
        "status" => f.status && to_string(f.status)
      }
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Map.new()

    ~p"/o/#{org(assigns)}/reports/maintenance.csv?#{query}"
  end

  defp vehicle_options(scope) do
    VehicleManagement.list_vehicles!(%{}, scope: scope, page: [limit: 500])
    |> Map.get(:results)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp money(%Decimal{} = amount, currency), do: "#{currency} #{Format.number(amount)}"

  defp humanize(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
