defmodule FleetmsWeb.ReportLive.Roster do
  @moduledoc """
  Vehicle roster report: the fleet with its identifying and status fields, filterable by
  status. Exports to CSV and prints. A straightforward inventory of the vehicles.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Reports
  alias Fleetms.VehicleManagement.VehicleStatus

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Vehicle roster"), active_link: :reports)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    report = Reports.vehicle_roster(socket.assigns.current_scope, params)

    {:noreply,
     socket
     |> assign(:report, report)
     |> assign(:status, report.filters.status)
     |> assign(:statuses, status_options())}
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
        %{label: gettext("Vehicle roster")}
      ]} />

      <.header>
        {gettext("Vehicle roster")}
        <:subtitle>{gettext("The fleet at a glance — status, identity and mileage.")}</:subtitle>
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
        <.input
          type="select"
          name="status"
          value={to_string(@status || "")}
          label={gettext("Status")}
          options={@statuses}
        />
      </form>

      <div id="report" class="mt-4">
        <div class="hidden print-only mb-4">
          <h1 class="text-lg font-bold">{gettext("Vehicle roster")}</h1>
        </div>

        <p class="mb-3 text-sm text-body">
          {gettext("%{n} vehicles", n: @report.summary.count)}
        </p>

        <div
          tabindex="0"
          role="region"
          aria-label="Driver roster table"
          class="overflow-x-auto rounded-base border border-default bg-white shadow-sm dark:bg-gray-800"
        >
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Name")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Make / model")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Plate")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Year")}</th>
                <th class="px-4 py-3 text-right font-semibold">{gettext("Mileage")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Purchased")}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={row <- @report.rows}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <td class="whitespace-nowrap px-4 py-3 font-medium text-heading">
                  <.link navigate={~p"/o/#{org(assigns)}/vehicles/#{row.id}"} class="hover:underline">
                    {row.name}
                  </.link>
                </td>
                <td class="px-4 py-3">{make_model(row)}</td>
                <td class="px-4 py-3">{humanize_status(row.status)}</td>
                <td class="px-4 py-3">{present(row.license_plate)}</td>
                <td class="px-4 py-3 text-right">{present(row.year)}</td>
                <td class="px-4 py-3 text-right">{Format.distance(row.mileage, org(assigns))}</td>
                <td class="whitespace-nowrap px-4 py-3">
                  {Format.date(row.purchase_date, org(assigns))}
                </td>
              </tr>
              <tr :if={@report.rows == []}>
                <td colspan="7" class="px-4 py-10 text-center text-body">
                  {gettext("No vehicles match.")}
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

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    query = if status in [nil, ""], do: %{}, else: %{"status" => status}
    {:noreply, push_patch(socket, to: ~p"/o/#{org(socket)}/reports/roster?#{query}")}
  end

  defp export_path(assigns) do
    query = if assigns.status, do: %{"status" => to_string(assigns.status)}, else: %{}
    ~p"/o/#{org(assigns)}/reports/roster.csv?#{query}"
  end

  defp make_model(%{make: nil, model: nil}), do: "—"

  defp make_model(%{make: make, model: model}),
    do: [make, model] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

  defp humanize_status(nil), do: "—"
  defp humanize_status(status), do: status |> to_string() |> String.replace("-", " ")

  defp present(nil), do: "—"
  defp present(""), do: "—"
  defp present(value), do: value

  defp status_options do
    [
      {"All statuses", ""}
      | Enum.map(VehicleStatus.values(), &{humanize_status(&1), to_string(&1)})
    ]
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
