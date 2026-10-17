defmodule FleetmsWeb.CalendarLive do
  @moduledoc """
  A month calendar that unifies the fleet's dated work — service reminders,
  renewals, issues and scheduled inspections — into one view, so users can see
  what's coming due without visiting each list. Backed by `Fleetms.Calendar`.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Calendar, as: FleetCalendar

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Calendar"), active_link: :calendar)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    month = parse_month(params["month"]) || Date.beginning_of_month(Date.utc_today())
    weeks = calendar_weeks(month)
    {grid_start, grid_end} = {List.first(List.first(weeks)), List.last(List.last(weeks))}

    events =
      socket.assigns.current_scope
      |> FleetCalendar.events(grid_start, grid_end)
      |> Enum.group_by(& &1.date)

    {:noreply,
     assign(socket,
       month: month,
       weeks: weeks,
       events_by_day: events,
       today: Date.utc_today()
     )}
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
        %{label: gettext("Calendar")}
      ]} />

      <.header>
        {gettext("Calendar")}
        <:subtitle>
          {gettext("Reminders, renewals, issues and inspections that are coming due.")}
        </:subtitle>
        <:actions>
          <.button variant="secondary" navigate={month_path(assigns, Date.utc_today())}>
            {gettext("Today")}
          </.button>
          <div class="flex items-center gap-1">
            <.button variant="secondary" size="sm" navigate={month_path(assigns, prev_month(@month))}>
              <.icon name="fa-chevron-left" class="text-xs" />
              <span class="sr-only">{gettext("Previous month")}</span>
            </.button>
            <.button variant="secondary" size="sm" navigate={month_path(assigns, next_month(@month))}>
              <.icon name="fa-chevron-right" class="text-xs" />
              <span class="sr-only">{gettext("Next month")}</span>
            </.button>
          </div>
        </:actions>
      </.header>

      <div class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-body">
        <span
          :for={type <- [:reminder, :renewal, :issue, :inspection, :license]}
          class="flex items-center gap-1.5"
        >
          <span class={["h-2.5 w-2.5 rounded-full", dot_class(type)]}></span>
          {type_label(type)}
        </span>
      </div>

      <p class="mt-4 text-lg font-semibold text-heading">
        {Calendar.strftime(@month, "%B %Y")}
      </p>

      <%!-- Month grid: desktop/tablet only. The 7-column grid needs ~720px, so on
            phones we show the agenda list below instead of a horizontally scrolling grid. --%>
      <div class="mt-2 hidden overflow-x-auto rounded-base border border-default bg-white shadow-sm dark:bg-gray-800 md:block">
        <div class="grid min-w-[720px] grid-cols-7 border-b border-default bg-gray-50 text-xs font-semibold uppercase text-heading dark:bg-gray-700">
          <div :for={label <- weekday_labels()} class="px-2 py-2 text-center">{label}</div>
        </div>

        <div class="grid min-w-[720px] grid-cols-7">
          <div
            :for={day <- List.flatten(@weeks)}
            class={[
              "min-h-28 border-b border-r border-default p-1.5 align-top",
              day.month != @month.month && "bg-gray-50/60 dark:bg-gray-900/30"
            ]}
          >
            <div class="mb-1 flex items-center justify-between">
              <span class={[
                "inline-flex h-6 w-6 items-center justify-center rounded-full text-xs",
                day == @today && "bg-primary-600 font-semibold text-white",
                day != @today && day.month == @month.month && "text-heading",
                day.month != @month.month && "text-gray-400"
              ]}>
                {day.day}
              </span>
            </div>

            <% events = Map.get(@events_by_day, day, []) %>
            <div class="space-y-1">
              <.link
                :for={event <- Enum.take(events, 3)}
                navigate={event_path(assigns, event)}
                title={"#{event.title}#{event.subtitle && " — #{event.subtitle}"}"}
                class={[
                  "block truncate rounded px-1.5 py-0.5 text-xs font-medium",
                  pill_class(event.type)
                ]}
              >
                {event.title}
              </.link>
              <p :if={length(events) > 3} class="px-1.5 text-xs text-body">
                {gettext("+%{count} more", count: length(events) - 3)}
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Agenda list: phones only. Lists this month's days that have something due. --%>
      <div class="mt-2 space-y-3 md:hidden">
        <% agenda =
          @weeks
          |> List.flatten()
          |> Enum.filter(&(&1.month == @month.month and Map.get(@events_by_day, &1, []) != [])) %>
        <div
          :if={agenda == []}
          class="rounded-base border border-default bg-white p-6 text-center text-sm text-body dark:bg-gray-800"
        >
          {gettext("Nothing due this month.")}
        </div>
        <div
          :for={day <- agenda}
          class="rounded-base border border-default bg-white p-3 shadow-sm dark:bg-gray-800"
        >
          <div class="mb-2 flex items-center gap-2">
            <span class={[
              "inline-flex h-7 w-7 items-center justify-center rounded-full text-sm",
              day == @today && "bg-primary-600 font-semibold text-white",
              day != @today && "text-heading"
            ]}>
              {day.day}
            </span>
            <span class="text-sm font-medium text-heading">
              {Calendar.strftime(day, "%A, %d %B")}
            </span>
          </div>
          <div class="space-y-1">
            <.link
              :for={event <- Map.get(@events_by_day, day, [])}
              navigate={event_path(assigns, event)}
              class={[
                "flex items-center gap-2 rounded px-2 py-1.5 text-sm font-medium",
                pill_class(event.type)
              ]}
            >
              <span class={["h-2 w-2 flex-none rounded-full", dot_class(event.type)]} />
              <span class="truncate">{event.title}</span>
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- month math -----------------------------------------------------------

  defp calendar_weeks(first_of_month) do
    last = Date.end_of_month(first_of_month)
    grid_start = Date.beginning_of_week(first_of_month, :monday)
    grid_end = Date.end_of_week(last, :monday)

    grid_start
    |> Date.range(grid_end)
    |> Enum.to_list()
    |> Enum.chunk_every(7)
  end

  defp prev_month(month), do: month |> Date.add(-1) |> Date.beginning_of_month()
  defp next_month(month), do: month |> Date.end_of_month() |> Date.add(1)

  defp parse_month(nil), do: nil

  defp parse_month(value) do
    case Date.from_iso8601(value <> "-01") do
      {:ok, date} -> Date.beginning_of_month(date)
      _ -> nil
    end
  end

  defp weekday_labels do
    [
      gettext("Mon"),
      gettext("Tue"),
      gettext("Wed"),
      gettext("Thu"),
      gettext("Fri"),
      gettext("Sat"),
      gettext("Sun")
    ]
  end

  # --- routes & styling -----------------------------------------------------

  defp month_path(assigns, %Date{} = date),
    do: ~p"/o/#{org(assigns)}/calendar?#{%{"month" => Calendar.strftime(date, "%Y-%m")}}"

  defp event_path(assigns, %{type: :reminder, id: id}),
    do: ~p"/o/#{org(assigns)}/service-reminders/#{id}/edit"

  defp event_path(assigns, %{type: :renewal, id: id}),
    do: ~p"/o/#{org(assigns)}/renewals/#{id}/edit"

  defp event_path(assigns, %{type: :issue, id: id}),
    do: ~p"/o/#{org(assigns)}/issues/#{id}"

  defp event_path(assigns, %{type: :inspection}),
    do: ~p"/o/#{org(assigns)}/inspection-assignments"

  defp event_path(assigns, %{type: :license, id: id}),
    do: ~p"/o/#{org(assigns)}/drivers/#{id}/edit"

  defp type_label(:reminder), do: gettext("Reminders")
  defp type_label(:renewal), do: gettext("Renewals")
  defp type_label(:issue), do: gettext("Issues")
  defp type_label(:inspection), do: gettext("Inspections")
  defp type_label(:license), do: gettext("Licences")

  defp dot_class(:reminder), do: "bg-amber-500"
  defp dot_class(:renewal), do: "bg-blue-500"
  defp dot_class(:issue), do: "bg-red-500"
  defp dot_class(:inspection), do: "bg-purple-500"
  defp dot_class(:license), do: "bg-teal-500"

  defp pill_class(:reminder),
    do: "bg-amber-100 text-amber-800 hover:bg-amber-200 dark:bg-amber-900/50 dark:text-amber-200"

  defp pill_class(:renewal),
    do: "bg-blue-100 text-blue-800 hover:bg-blue-200 dark:bg-blue-900/50 dark:text-blue-200"

  defp pill_class(:issue),
    do: "bg-red-100 text-red-800 hover:bg-red-200 dark:bg-red-900/50 dark:text-red-200"

  defp pill_class(:inspection),
    do:
      "bg-purple-100 text-purple-800 hover:bg-purple-200 dark:bg-purple-900/50 dark:text-purple-200"

  defp pill_class(:license),
    do: "bg-teal-100 text-teal-800 hover:bg-teal-200 dark:bg-teal-900/50 dark:text-teal-200"

  defp org(assigns), do: assigns.current_scope.organization
end
