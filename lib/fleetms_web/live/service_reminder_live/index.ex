defmodule FleetmsWeb.ServiceReminderLive.Index do
  @moduledoc """
  Lists an organization's service reminders with free-text search, a filter drawer
  (due status, vehicle, service task), a sortable "next due" column and pagination.
  The status shown is derived live from each vehicle's current mileage and today.
  Rows open a reminder for editing; a reminder can be snoozed, reset (marked
  serviced), archived or restored inline. All list state lives in the URL.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Format
  alias Fleetms.Maintenance
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  @limit 20
  @sortable ~w(next_due_date next_due_mileage inserted_at)a
  @due_statuses ~w(upcoming due_soon overdue)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Service Reminders"), active_link: :maintenance)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    archived? = params["archived"] == "1"
    sort_by = sort_by(params["sort"], @sortable, :next_due_date)
    sort_order = sort_order_asc(params["dir"])
    filters = parse_filters(params)
    page = page_number(params["page"])

    args = %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order}

    opts = [scope: scope, page: [limit: @limit, offset: (page - 1) * @limit, count: true]]

    result =
      if archived? do
        Maintenance.list_archived_service_reminders(args, opts)
      else
        Maintenance.list_service_reminders(args, opts)
      end

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            reminders: page_data.results,
            count: page_data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            due_statuses: @due_statuses,
            vehicles: vehicle_options(scope),
            tasks: task_options(scope),
            can_create: Scope.has_permission?(scope, :create_service_reminder),
            can_update: Scope.has_permission?(scope, :update_service_reminder),
            can_delete: Scope.has_permission?(scope, :delete_service_reminder),
            can_create_work_order: Scope.has_permission?(scope, :create_work_order)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to service reminders here."))
          |> push_navigate(to: ~p"/o/#{org(socket)}")

        {:error, error} ->
          raise error
      end

    {:noreply, socket}
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
        %{label: gettext("Service Reminders")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived reminders"), else: gettext("Service Reminders")}
        <:subtitle>
          {if @archived_view,
            do: gettext("Archived reminders can be restored."),
            else: gettext("%{count} upcoming service tasks.", count: @count)}
        </:subtitle>
        <:actions>
          <.button :if={@can_update} variant="secondary" navigate={toggle_archived_path(assigns)}>
            <.icon
              name={if @archived_view, do: "fa-arrow-left-long", else: "fa-box-archive"}
              class="me-2"
            />
            {if @archived_view, do: gettext("Back to active"), else: gettext("Show archived")}
          </.button>
          <.button
            :if={@can_create and not @archived_view}
            navigate={~p"/o/#{org(assigns)}/service-reminders/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New reminder")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          query={@query}
          filter_count={map_size(@filters)}
          drawer_id="reminder-filters"
          placeholder={gettext("Search by vehicle or task…")}
        />

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Service task")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                <.sort_th
                  label={gettext("Next due")}
                  field="next_due_date"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={r <- @reminders}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, r)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {r.vehicle_name}
                </th>
                <td phx-click={row_navigate(assigns, r)} class="cursor-pointer px-4 py-3">
                  {r.service_task_name}
                </td>
                <td phx-click={row_navigate(assigns, r)} class="cursor-pointer px-4 py-3">
                  <.due_badge status={r.due_status} />
                </td>
                <td phx-click={row_navigate(assigns, r)} class="cursor-pointer px-4 py-3">
                  {next_due(r, org(assigns))}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={r.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <details
                      :if={
                        (not @archived_view and @can_update and r.next_due_date) &&
                          r.due_status in [:due_soon, :overdue]
                      }
                      class="group relative"
                    >
                      <summary class="inline-flex cursor-pointer list-none items-center rounded-lg border border-default bg-white px-3 py-1.5 text-xs font-medium text-body hover:bg-gray-50 dark:bg-gray-800 dark:hover:bg-gray-700">
                        <.icon name="fa-clock" class="me-1 text-xs" /> {gettext("Snooze")}
                      </summary>
                      <div class="absolute right-0 z-10 mt-1 w-36 overflow-hidden rounded-lg border border-default bg-white shadow-lg dark:bg-gray-800">
                        <button
                          :for={{label, days} <- snooze_options()}
                          type="button"
                          phx-click="snooze"
                          phx-value-id={r.id}
                          phx-value-days={days}
                          class="block w-full px-3 py-2 text-left text-xs text-body hover:bg-gray-50 dark:hover:bg-gray-700"
                        >
                          {label}
                        </button>
                      </div>
                    </details>
                    <.button
                      :if={not @archived_view and @can_create_work_order and r.vehicle_id}
                      size="xs"
                      variant="secondary"
                      navigate={
                        ~p"/o/#{org(assigns)}/work-orders/new?#{%{"vehicle_id" => r.vehicle_id}}"
                      }
                      title={gettext("Create a work order for this vehicle")}
                    >
                      <.icon name="fa-screwdriver-wrench" class="me-1 text-xs" /> {gettext(
                        "Work order"
                      )}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="reset"
                      phx-value-id={r.id}
                      data-confirm={gettext("Mark this service done and re-baseline the reminder?")}
                    >
                      {gettext("Mark done")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={r.id}
                      data-confirm={
                        gettext("Archive this reminder? You can restore it later from Show archived.")
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@reminders == []}>
                <td colspan="5" class="px-4 py-6">
                  <.empty_state
                    icon="fa-bell"
                    title={
                      if @archived_view,
                        do: gettext("No archived reminders"),
                        else: gettext("No service reminders found")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Add a reminder to stay ahead of maintenance.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/service-reminders/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New reminder")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer id="reminder-filters">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Due status")}</span>
          <div class="space-y-2">
            <label :for={st <- @due_statuses} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="due_status[]"
                value={st}
                checked={st in (@filters["due_statuses"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {due_status_label(st)}
            </label>
          </div>
        </div>

        <.search_select
          id="filter_rem_vehicle_id"
          name="vehicle_id"
          value={@filters["vehicle_id"]}
          label={gettext("Vehicle")}
          prompt={gettext("Any vehicle")}
          options={@vehicles}
        />
        <.search_select
          id="filter_rem_service_task_id"
          name="service_task_id"
          value={@filters["service_task_id"]}
          label={gettext("Service task")}
          prompt={gettext("Any task")}
          options={@tasks}
        />
      </.filter_drawer>
    </Layouts.app>
    """
  end

  attr :status, :atom, required: true

  def due_badge(assigns) do
    {label, classes} =
      case assigns.status do
        :upcoming ->
          {gettext("Upcoming"), "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"}

        :due_soon ->
          {gettext("Due soon"),
           "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"}

        :overdue ->
          {gettext("Overdue"), "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"}
      end

    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={["rounded-full px-2.5 py-0.5 text-xs font-medium", @classes]}>{@label}</span>
    """
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"q" => nilify(q), "page" => nil}))}
  end

  def handle_event("sort", %{"by" => by}, socket) do
    {sort, dir} =
      next_sort(
        socket.assigns.sort_by,
        socket.assigns.sort_order,
        sort_by(by, @sortable, :next_due_date)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    overrides = %{
      "due_status" => params["due_status"] || [],
      "vehicle_id" => nilify(params["vehicle_id"]),
      "service_task_id" => nilify(params["service_task_id"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    base = %{"q" => socket.assigns.query, "archived" => archived_param(socket)}
    {:noreply, push_patch(socket, to: ~p"/o/#{org(socket)}/service-reminders?#{prune(base)}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("reset", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, reminder} <- Maintenance.get_service_reminder(id, scope: scope),
         {:ok, _} <- Maintenance.reset_service_reminder(reminder, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Reminder reset."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not reset that reminder."))}
    end
  end

  def handle_event("snooze", %{"id" => id, "days" => days}, socket) do
    scope = socket.assigns.current_scope
    days = String.to_integer(days)

    with {:ok, reminder} <- Maintenance.get_service_reminder(id, scope: scope),
         {:ok, _} <- Maintenance.snooze_service_reminder(reminder, days, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Reminder snoozed for %{n} days.", n: days))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not snooze that reminder."))}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, reminder} <- Maintenance.get_service_reminder(id, scope: scope),
         :ok <- Maintenance.delete_service_reminder(reminder, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Reminder archived. Restore it any time from Show archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that reminder."))}
    end
  end

  # Archived reminders are hidden from `get_service_reminder`, so restore the record we
  # already loaded into the archived list rather than looking it up.
  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with reminder when not is_nil(reminder) <-
           Enum.find(socket.assigns.reminders, &(&1.id == id)),
         {:ok, _} <- Maintenance.restore_service_reminder(reminder, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Reminder restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      {:error, %Ash.Error.Invalid{}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Can't restore: this vehicle already has a live reminder for that service.")
         )}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not restore that reminder."))}
    end
  end

  # --- URL <-> state ---

  defp index_path(socket, overrides) do
    f = socket.assigns.filters

    params =
      %{
        "q" => socket.assigns.query,
        "archived" => archived_param(socket),
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "due_status" => f["due_statuses"] || [],
        "vehicle_id" => f["vehicle_id"],
        "service_task_id" => f["service_task_id"]
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/service-reminders?#{params}"
  end

  defp archived_param(socket), do: if(socket.assigns.archived_view, do: "1")

  defp parse_filters(params) do
    %{
      "due_statuses" => Enum.filter(List.wrap(params["due_status"]), &(&1 in @due_statuses)),
      "vehicle_id" => nilify(params["vehicle_id"]),
      "service_task_id" => nilify(params["service_task_id"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/service-reminders"
    else
      ~p"/o/#{org(assigns)}/service-reminders?#{%{"archived" => "1"}}"
    end
  end

  defp due_status_label("upcoming"), do: gettext("Upcoming")
  defp due_status_label("due_soon"), do: gettext("Due soon")
  defp due_status_label("overdue"), do: gettext("Overdue")
  defp due_status_label(other), do: other

  defp next_due(reminder, org) do
    [mileage_due(reminder, org), date_due(reminder, org)]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> "—"
      parts -> Enum.join(parts, " · ")
    end
  end

  defp mileage_due(%{next_due_mileage: nil}, _org), do: nil
  defp mileage_due(%{next_due_mileage: m}, org), do: Format.distance(m, org)

  defp date_due(%{next_due_date: nil}, _org), do: nil
  defp date_due(%{next_due_date: d}, org), do: Format.date(d, org)

  defp snooze_options do
    [{gettext("1 week"), 7}, {gettext("2 weeks"), 14}, {gettext("1 month"), 30}]
  end

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp task_options(scope) do
    case Maintenance.list_service_tasks(%{}, scope: scope, page: [limit: 200, offset: 0]) do
      {:ok, page} -> Enum.map(page.results, &{&1.name, &1.id})
      _ -> []
    end
  end

  # Reminders default to the nearest-due first (ascending).
  defp sort_order_asc(nil), do: :asc
  defp sort_order_asc(value), do: sort_order(value)

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(%{archived_view: true}, _reminder), do: nil

  defp row_navigate(assigns, reminder),
    do: JS.navigate(~p"/o/#{org(assigns)}/service-reminders/#{reminder.id}/edit")
end
