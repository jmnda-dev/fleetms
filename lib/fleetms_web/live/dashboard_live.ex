defmodule FleetmsWeb.DashboardLive do
  @moduledoc """
  The organization home page (`/o/:org_id`) — the fleet dashboard.

  This first pass shows the operational pulse: KPI tiles for vehicles, issues, work
  orders and upcoming maintenance, plus a fleet-status breakdown. The figures come from
  `Fleetms.Dashboard`. Trend charts and the "needs attention" lists follow in later
  passes. The `current_scope` / `current_organization` / `organizations` assigns come
  from the `:require_organization` on_mount hook.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Dashboard
  alias Fleetms.Format

  # Vehicle statuses in a sensible reading order, each with a chip/segment colour.
  @status_order [
    {:Active, "bg-green-500", "text-green-700 dark:text-green-300"},
    {:Maintenance, "bg-amber-500", "text-amber-700 dark:text-amber-300"},
    {:"Out-of-Service", "bg-red-500", "text-red-700 dark:text-red-300"},
    {:Inactive, "bg-slate-400", "text-slate-600 dark:text-slate-300"},
    {:Sold, "bg-gray-400", "text-gray-600 dark:text-gray-300"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Dashboard"), active_link: :dashboard)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope

    {:noreply,
     socket
     |> assign(:summary, Dashboard.summary(scope))
     |> assign(:charts, build_charts(scope))
     |> assign(:reminders, Dashboard.due_reminders(scope))
     |> assign(:renewals, Dashboard.due_renewals(scope))
     |> assign(:recent_issues, Dashboard.recent_issues(scope))
     |> assign(:low_stock, Dashboard.low_stock_parts(scope))
     |> assign(:billing_notice, billing_notice(scope))
     |> assign_onboarding(scope)}
  end

  # Only the owner sees (and can act on) billing; others aren't shown dunning.
  defp billing_notice(scope) do
    if Fleetms.Scope.owner?(scope) do
      Fleetms.Billing.Entitlement.notice_for_organization(scope.organization.id)
    end
  end

  # A getting-started checklist for a fresh org, shown only to members who can
  # set the fleet up and only until all steps are done. Steps are derived from
  # real data, so they tick themselves off as the user works.
  defp assign_onboarding(socket, scope) do
    if Fleetms.Scope.has_permission?(scope, :create_vehicle) do
      counts = Dashboard.onboarding(scope)

      steps = [
        %{
          done?: counts.vehicles > 0,
          title: gettext("Add your first vehicle"),
          desc: gettext("Build your fleet so everything else can hang off it."),
          cta: gettext("Add a vehicle"),
          path: ~p"/o/#{scope.organization}/vehicles/new"
        },
        %{
          done?: counts.issues > 0,
          title: gettext("Report an issue"),
          desc: gettext("Capture a fault or defect against a vehicle."),
          cta: gettext("Report an issue"),
          path: ~p"/o/#{scope.organization}/issues/new"
        },
        %{
          done?: counts.reminders > 0,
          title: gettext("Schedule a service reminder"),
          desc: gettext("Stay ahead of maintenance with a recurring reminder."),
          cta: gettext("Add a reminder"),
          path: ~p"/o/#{scope.organization}/service-reminders/new"
        }
      ]

      assign(socket,
        onboarding_steps: steps,
        onboarding_done: Enum.count(steps, & &1.done?),
        onboarding_complete: Enum.all?(steps, & &1.done?)
      )
    else
      assign(socket, onboarding_steps: [], onboarding_done: 0, onboarding_complete: true)
    end
  end

  # Each chart is a small JSON spec the `Chart` hook feeds to ECharts (see chartOption.js).
  defp build_charts(scope) do
    trend = Dashboard.issues_trend(scope)
    maintenance = Dashboard.maintenance_spend(scope)
    fuel = Dashboard.fuel_spend(scope)
    priority = Dashboard.open_issues_by_priority(scope)

    %{
      issues_trend:
        Jason.encode!(%{
          kind: "line",
          categories: trend.categories,
          series: [
            %{name: gettext("Opened"), data: trend.opened, color: 1},
            %{name: gettext("Resolved"), data: trend.resolved, color: 2}
          ]
        }),
      spend:
        Jason.encode!(%{
          kind: "bar",
          categories: maintenance.categories,
          series: [
            %{name: gettext("Maintenance"), data: maintenance.values, color: 1},
            %{name: gettext("Fuel"), data: fuel.values, color: 2}
          ],
          valueFormat: "money",
          currency: maintenance.currency
        }),
      issues_priority:
        Jason.encode!(%{
          kind: "bar",
          categories: priority.categories,
          series: [%{name: gettext("Open issues"), data: priority.values, color: 1}]
        })
    }
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
      <.header>
        {gettext("Dashboard")}
        <:subtitle>{Fleetms.Scope.workspace_name(@current_scope)}</:subtitle>
      </.header>

      <div
        :if={@billing_notice}
        class={[
          "mt-4 flex flex-wrap items-center justify-between gap-3 rounded-base border p-4",
          if(@billing_notice == :expired,
            do: "border-red-300 bg-red-50 dark:border-red-800 dark:bg-red-900/20",
            else: "border-amber-300 bg-amber-50 dark:border-amber-800 dark:bg-amber-900/20"
          )
        ]}
      >
        <div class="flex items-start gap-3">
          <.icon
            name="fa-triangle-exclamation"
            class="mt-0.5 size-5 text-amber-600 dark:text-amber-400"
          />
          <div>
            <p class="font-semibold text-heading">
              {if @billing_notice == :expired,
                do: gettext("Your subscription has expired"),
                else: gettext("A payment is due")}
            </p>
            <p class="text-sm text-body">
              {if @billing_notice == :expired,
                do: gettext("Renew to keep full access to your fleet."),
                else: gettext("Settle your open invoice to stay active.")}
            </p>
          </div>
        </div>
        <.link
          navigate={~p"/o/#{@current_scope.organization}/billing"}
          class="shrink-0 rounded-base bg-primary-700 px-4 py-2 text-sm font-semibold text-white hover:bg-primary-800"
        >
          {gettext("Go to billing")}
        </.link>
      </div>

      <div
        :if={not @onboarding_complete and Fleetms.FeatureFlags.onboarding_checklist?()}
        id="onboarding-checklist"
        data-key={"onboarding-dismissed:#{@current_scope.organization.id}"}
        phx-hook="Dismissable"
        class="mt-6 rounded-base border border-primary-200 bg-primary-50 p-5 dark:border-primary-900 dark:bg-primary-900/20"
      >
        <div class="flex items-start justify-between gap-4">
          <div>
            <h2 class="text-base font-semibold text-heading">
              <.icon name="fa-rocket" class="me-1 text-primary-600" /> {gettext("Get started")}
            </h2>
            <p class="mt-0.5 text-sm text-body">
              {gettext("A few steps to set your fleet up. %{done} of %{total} done.",
                done: @onboarding_done,
                total: length(@onboarding_steps)
              )}
            </p>
          </div>
          <button
            type="button"
            data-dismiss
            class="shrink-0 rounded-lg p-1.5 text-gray-400 hover:bg-primary-100 hover:text-gray-600 dark:hover:bg-primary-900/40"
            aria-label={gettext("Dismiss")}
          >
            <.icon name="fa-xmark" />
          </button>
        </div>

        <ul class="mt-4 space-y-2">
          <li
            :for={step <- @onboarding_steps}
            class="flex items-center gap-3 rounded-lg bg-white px-3 py-2.5 dark:bg-gray-800"
          >
            <i class={[
              "fa-solid text-lg",
              step.done? && "fa-circle-check text-green-500",
              !step.done? && "fa-circle text-gray-300 dark:text-gray-600"
            ]}>
            </i>
            <div class="min-w-0 flex-1">
              <p class={[
                "text-sm font-medium",
                step.done? && "text-body line-through",
                !step.done? && "text-heading"
              ]}>
                {step.title}
              </p>
              <p :if={not step.done?} class="text-xs text-body">{step.desc}</p>
            </div>
            <.button :if={not step.done?} navigate={step.path} size="sm" variant="secondary">
              {step.cta}
            </.button>
          </li>
        </ul>
      </div>

      <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_vehicles)}
          label={gettext("Active vehicles")}
          value={active_vehicles(@summary)}
          sub={gettext("of %{n} in fleet", n: fleet_size(@summary))}
          icon="fa-truck"
          tone="brand"
          navigate={~p"/o/#{org(assigns)}/vehicles"}
        />
        <.stat_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_issues)}
          label={gettext("Open issues")}
          value={@summary.open_issues}
          sub={
            if @summary.overdue_issues > 0,
              do: gettext("%{n} overdue", n: @summary.overdue_issues)
          }
          sub_tone={:danger}
          icon="fa-triangle-exclamation"
          tone="amber"
          navigate={~p"/o/#{org(assigns)}/issues"}
        />
        <.stat_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_work_orders)}
          label={gettext("Work orders in progress")}
          value={@summary.work_orders_in_progress}
          sub={gettext("%{n} open", n: @summary.work_orders_open)}
          icon="fa-screwdriver-wrench"
          tone="blue"
          navigate={~p"/o/#{org(assigns)}/work-orders"}
        />
        <.stat_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_service_reminders)}
          label={gettext("Coming due")}
          value={@summary.reminders_due + @summary.renewals_due}
          sub={
            gettext("%{r} services · %{v} renewals",
              r: @summary.reminders_due,
              v: @summary.renewals_due
            )
          }
          icon="fa-bell"
          tone="purple"
          navigate={~p"/o/#{org(assigns)}/service-reminders"}
        />
      </div>

      <section
        :if={Fleetms.Scope.has_permission?(@current_scope, :view_vehicles)}
        class="mt-6 rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800"
      >
        <div class="mb-4 flex items-baseline justify-between">
          <h2 class="text-sm font-semibold uppercase text-heading">{gettext("Fleet status")}</h2>
          <span class="text-sm text-body">
            {gettext("%{n} vehicles", n: total_vehicles(@summary))}
          </span>
        </div>

        <.status_bar summary={@summary} />

        <div class="mt-4 flex flex-wrap gap-x-6 gap-y-2">
          <div :for={{status, dot, text} <- status_legend(@summary)} class="flex items-center gap-2">
            <span class={["h-2.5 w-2.5 rounded-full", dot]} />
            <span class="text-sm text-body">{humanize_status(status)}</span>
            <span class={["text-sm font-semibold", text]}>{@summary.vehicle_status[status]}</span>
          </div>
          <p :if={total_vehicles(@summary) == 0} class="text-sm text-body">
            {gettext("No vehicles yet.")}
          </p>
        </div>
      </section>

      <div class="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <.chart_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_issues)}
          id="chart-issues-trend"
          title={gettext("Issues opened vs resolved")}
          sub={gettext("Last 6 months")}
          spec={@charts.issues_trend}
          class="lg:col-span-2"
        />
        <.chart_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_work_orders)}
          id="chart-spend"
          title={gettext("Spend")}
          sub={gettext("Maintenance & fuel · last 6 months")}
          spec={@charts.spend}
        />
        <.chart_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_issues)}
          id="chart-issues-priority"
          title={gettext("Open issues by priority")}
          spec={@charts.issues_priority}
        />
      </div>

      <div class="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <.attention_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_service_reminders)}
          title={gettext("Service due")}
          icon="fa-bell"
          empty={gettext("Nothing due right now.")}
          view_all={~p"/o/#{org(assigns)}/service-reminders"}
          rows={@reminders}
        >
          <:row :let={r}>
            <.attention_row
              primary={r.task}
              secondary={r.vehicle}
              href={~p"/o/#{org(assigns)}/service-reminders/#{r.id}/edit"}
            >
              <.due_pill overdue={r.status == :overdue} />
            </.attention_row>
          </:row>
        </.attention_card>

        <.attention_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_renewals)}
          title={gettext("Renewals due")}
          icon="fa-file-contract"
          empty={gettext("No renewals coming up.")}
          view_all={~p"/o/#{org(assigns)}/renewals"}
          rows={@renewals}
        >
          <:row :let={r}>
            <.attention_row primary={r.type} secondary={r.vehicle}>
              <div class="flex items-center gap-2">
                <span class="text-xs text-body">{Format.date(r.due_date, org(assigns))}</span>
                <.due_pill overdue={r.status == "Overdue"} />
              </div>
            </.attention_row>
          </:row>
        </.attention_card>

        <.attention_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_issues)}
          title={gettext("Recently reported issues")}
          icon="fa-triangle-exclamation"
          empty={gettext("No issues reported yet.")}
          view_all={~p"/o/#{org(assigns)}/issues"}
          rows={@recent_issues}
        >
          <:row :let={i}>
            <.attention_row
              primary={i.title}
              secondary={i.vehicle}
              href={~p"/o/#{org(assigns)}/issues/#{i.id}"}
            >
              <span class="whitespace-nowrap text-xs text-body">
                {Format.date(i.reported_at, org(assigns))}
              </span>
            </.attention_row>
          </:row>
        </.attention_card>

        <.attention_card
          :if={Fleetms.Scope.has_permission?(@current_scope, :view_parts)}
          title={gettext("Low stock")}
          icon="fa-box-open"
          empty={gettext("Stock levels look healthy.")}
          view_all={~p"/o/#{org(assigns)}/parts"}
          rows={@low_stock}
        >
          <:row :let={p}>
            <.attention_row primary={p.name || p.part_number} secondary={p.part_number}>
              <span class={[
                "rounded-full px-2 py-0.5 text-xs font-medium",
                stock_pill(p.status)
              ]}>
                {gettext("%{n} on hand", n: Format.number(p.on_hand))}
              </span>
            </.attention_row>
          </:row>
        </.attention_card>
      </div>
    </Layouts.app>
    """
  end

  # --- attention list components ---

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :empty, :string, required: true
  attr :view_all, :string, required: true
  attr :rows, :list, required: true
  slot :row, required: true

  defp attention_card(assigns) do
    ~H"""
    <section class="rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
      <div class="flex items-center justify-between border-b border-default px-5 py-3">
        <h2 class="flex items-center gap-2 text-sm font-semibold uppercase text-heading">
          <.icon name={@icon} class="text-body" /> {@title}
        </h2>
        <.link navigate={@view_all} class="text-xs font-medium text-fg-brand hover:underline">
          {gettext("View all")}
        </.link>
      </div>
      <ul :if={@rows != []} class="divide-y divide-default">
        <li :for={row <- @rows} class="px-5 py-3">
          {render_slot(@row, row)}
        </li>
      </ul>
      <p :if={@rows == []} class="px-5 py-8 text-center text-sm text-body">{@empty}</p>
    </section>
    """
  end

  attr :primary, :string, required: true
  attr :secondary, :string, default: nil
  attr :href, :string, default: nil
  slot :inner_block, required: true

  defp attention_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3">
      <div class="min-w-0">
        <.link
          :if={@href}
          navigate={@href}
          class="block truncate text-sm font-medium text-heading hover:text-fg-brand"
        >
          {@primary}
        </.link>
        <span :if={!@href} class="block truncate text-sm font-medium text-heading">
          {@primary}
        </span>
        <span :if={@secondary} class="block truncate text-xs text-body">{@secondary}</span>
      </div>
      <div class="shrink-0">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr :overdue, :boolean, required: true

  defp due_pill(assigns) do
    ~H"""
    <span class={[
      "whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium",
      if(@overdue,
        do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300",
        else: "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"
      )
    ]}>
      {if @overdue, do: gettext("Overdue"), else: gettext("Due soon")}
    </span>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :sub, :string, default: nil
  attr :spec, :string, required: true
  attr :class, :string, default: nil

  defp chart_card(assigns) do
    ~H"""
    <section class={[
      "rounded-base border border-default bg-white p-5 shadow-sm dark:bg-gray-800",
      @class
    ]}>
      <div class="mb-3 flex items-baseline justify-between">
        <h2 class="text-sm font-semibold uppercase text-heading">{@title}</h2>
        <span :if={@sub} class="text-xs text-body">{@sub}</span>
      </div>
      <div id={@id} phx-hook="Chart" phx-update="ignore" data-spec={@spec} class="h-72"></div>
    </section>
    """
  end

  # --- components ---

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :sub, :string, default: nil
  attr :sub_tone, :atom, default: :muted
  attr :icon, :string, required: true
  attr :tone, :string, default: "brand"
  attr :navigate, :string, default: nil

  defp stat_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="group block rounded-base border border-default bg-white p-5 shadow-sm transition hover:border-brand hover:shadow-md dark:bg-gray-800"
    >
      <div class="flex items-start justify-between">
        <div>
          <p class="text-sm font-medium text-body">{@label}</p>
          <p class="mt-2 text-3xl font-bold text-heading">{@value}</p>
          <p :if={@sub} class={["mt-1 text-xs", sub_tone_class(@sub_tone)]}>{@sub}</p>
        </div>
        <span class={[
          "flex h-10 w-10 shrink-0 items-center justify-center rounded-lg",
          tone_class(@tone)
        ]}>
          <.icon name={@icon} />
        </span>
      </div>
    </.link>
    """
  end

  attr :summary, :map, required: true

  defp status_bar(assigns) do
    ~H"""
    <div class="flex h-3 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-gray-700">
      <div
        :for={{status, dot, _text} <- status_legend(@summary)}
        class={dot}
        style={"width: #{segment_pct(@summary, status)}%"}
        title={"#{humanize_status(status)}: #{@summary.vehicle_status[status]}"}
      >
      </div>
    </div>
    """
  end

  # --- derivations ---

  defp active_vehicles(summary), do: summary.vehicle_status[:Active] || 0

  # The working fleet excludes sold vehicles; total (for the status card) includes all.
  defp fleet_size(summary),
    do: total_vehicles(summary) - (summary.vehicle_status[:Sold] || 0)

  defp total_vehicles(summary), do: summary.vehicle_status |> Map.values() |> Enum.sum()

  # Only the statuses that actually have vehicles, in reading order — for the bar + legend.
  defp status_legend(summary) do
    Enum.filter(@status_order, fn {status, _dot, _text} -> summary.vehicle_status[status] > 0 end)
  end

  defp segment_pct(summary, status) do
    total = total_vehicles(summary)
    if total == 0, do: 0, else: Float.round(summary.vehicle_status[status] * 100 / total, 1)
  end

  defp humanize_status(status), do: status |> to_string() |> String.replace("-", " ")

  defp tone_class("brand"), do: "bg-brand-soft text-fg-brand"

  defp tone_class("amber"),
    do: "bg-amber-100 text-amber-600 dark:bg-amber-900 dark:text-amber-300"

  defp tone_class("blue"), do: "bg-blue-100 text-blue-600 dark:bg-blue-900 dark:text-blue-300"

  defp tone_class("purple"),
    do: "bg-purple-100 text-purple-600 dark:bg-purple-900 dark:text-purple-300"

  defp tone_class(_), do: "bg-brand/10 text-brand"

  defp sub_tone_class(:danger), do: "font-medium text-fg-danger"
  defp sub_tone_class(_), do: "text-body"

  defp stock_pill("Out of stock"), do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"
  defp stock_pill(_low), do: "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"

  defp org(assigns), do: assigns.current_scope.organization
end
