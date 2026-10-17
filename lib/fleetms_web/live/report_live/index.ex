defmodule FleetmsWeb.ReportLive.Index do
  @moduledoc """
  The reports landing page: a card per report. Only reports that are built link through;
  the rest are shown as "coming soon" so the section reads as a whole.
  """
  use FleetmsWeb, :live_view

  @reports [
    %{
      key: :maintenance,
      title: "Maintenance & cost history",
      description: "Work orders over a period with their parts, labour and total cost.",
      icon: "fa-screwdriver-wrench",
      path: :maintenance
    },
    %{
      key: :cost_of_ownership,
      title: "Cost of ownership",
      description: "Total spend per vehicle — maintenance and fuel — with cost per km.",
      icon: "fa-coins",
      path: :cost_of_ownership
    },
    %{
      key: :fuel,
      title: "Fuel & economy",
      description: "Fuel logged over a period, with cost and economy per vehicle.",
      icon: "fa-gas-pump",
      path: :fuel
    },
    %{
      key: :roster,
      title: "Vehicle roster",
      description: "The full fleet with status, make/model, mileage and purchase details.",
      icon: "fa-truck",
      path: :roster
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: gettext("Reports"), active_link: :reports, reports: @reports)}
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
        %{label: gettext("Reports")}
      ]} />

      <.header>
        {gettext("Reports")}
        <:subtitle>{gettext("Pull the numbers, filter them, and export to CSV or print.")}</:subtitle>
      </.header>

      <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <.report_card :for={report <- @reports} report={report} org={org(assigns)} />
      </div>
    </Layouts.app>
    """
  end

  attr :report, :map, required: true
  attr :org, :any, required: true

  defp report_card(%{report: %{path: nil}} = assigns) do
    ~H"""
    <div class="flex items-start gap-4 rounded-base border border-default bg-white p-5 opacity-70 shadow-sm dark:bg-gray-800">
      <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-gray-100 text-body dark:bg-gray-700">
        <.icon name={@report.icon} />
      </span>
      <div>
        <div class="flex items-center gap-2">
          <h2 class="font-semibold text-heading">{@report.title}</h2>
          <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-body dark:bg-gray-700">
            {gettext("Soon")}
          </span>
        </div>
        <p class="mt-1 text-sm text-body">{@report.description}</p>
      </div>
    </div>
    """
  end

  defp report_card(assigns) do
    ~H"""
    <.link
      navigate={report_path(@org, @report.key)}
      class="group flex items-start gap-4 rounded-base border border-default bg-white p-5 shadow-sm transition hover:border-brand hover:shadow-md dark:bg-gray-800"
    >
      <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-brand-soft text-fg-brand">
        <.icon name={@report.icon} />
      </span>
      <div>
        <h2 class="font-semibold text-heading group-hover:text-fg-brand">{@report.title}</h2>
        <p class="mt-1 text-sm text-body">{@report.description}</p>
      </div>
    </.link>
    """
  end

  # A verified route per built report (each `~p` is a static path the compiler can check).
  defp report_path(org, :maintenance), do: ~p"/o/#{org}/reports/maintenance"
  defp report_path(org, :cost_of_ownership), do: ~p"/o/#{org}/reports/cost-of-ownership"
  defp report_path(org, :fuel), do: ~p"/o/#{org}/reports/fuel"
  defp report_path(org, :roster), do: ~p"/o/#{org}/reports/roster"

  defp org(assigns), do: assigns.current_scope.organization
end
