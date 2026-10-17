defmodule FleetmsWeb.InspectionScheduleLive.Index do
  @moduledoc """
  Lists an organization's recurring inspection schedules — which form is due on
  which vehicle, how often, and how many assignments are currently open. Supports
  search, a filter drawer (vehicle, form, active/paused), sortable columns and
  pagination, with all list state in the URL.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Inspections
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  @limit 20
  @sortable ~w(interval_days open_assignment_count inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Inspection Schedules"), active_link: :inspections)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    sort_by = sort_by(params["sort"], @sortable, :inserted_at)
    sort_order = sort_order(params["dir"])
    vehicle_id = nilify(params["vehicle_id"])
    form_id = nilify(params["inspection_form_id"])
    active = parse_active(params["active"])
    page = page_number(params["page"])

    filters = (active && %{"active" => active}) || %{}

    args = %{
      search_query: query,
      vehicle_id: vehicle_id,
      inspection_form_id: form_id,
      filters: filters,
      sort_by: sort_by,
      sort_order: sort_order
    }

    result =
      Inspections.list_inspection_schedules(args,
        scope: scope,
        page: [limit: @limit, offset: (page - 1) * @limit, count: true]
      )

    socket =
      case result do
        {:ok, data} ->
          assign(socket,
            schedules: data.results,
            count: data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            vehicle_id: vehicle_id,
            form_id: form_id,
            active: active,
            filter_count: filter_count(vehicle_id, form_id, active),
            vehicles: vehicle_options(scope),
            forms: form_options(scope),
            can_create: Scope.has_permission?(scope, :create_inspection_schedule),
            can_update: Scope.has_permission?(scope, :update_inspection_schedule),
            can_delete: Scope.has_permission?(scope, :delete_inspection_schedule)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to inspection schedules here."))
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
        %{label: gettext("Inspection Schedules")}
      ]} />

      <.header>
        {gettext("Inspection Schedules")}
        <:subtitle>
          {gettext("Have a form filled against a vehicle on a repeating cadence.")}
        </:subtitle>
        <:actions>
          <.button :if={@can_create} navigate={~p"/o/#{org(assigns)}/inspection-schedules/new"}>
            <.icon name="fa-plus" class="me-2" /> {gettext("New schedule")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          query={@query}
          filter_count={@filter_count}
          drawer_id="schedule-filters"
          placeholder={gettext("Search vehicle or form…")}
        />

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Form")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <.sort_th
                  label={gettext("Repeats")}
                  field="interval_days"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Open")}
                  field="open_assignment_count"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={schedule <- @schedules}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <td class="px-4 py-3 font-medium text-heading">
                  {schedule.inspection_form.title}
                  <span
                    :if={schedule.name}
                    class="block text-xs font-normal text-gray-500 dark:text-gray-400"
                  >
                    {schedule.name}
                  </span>
                </td>
                <td class="whitespace-nowrap px-4 py-3">{schedule.vehicle.name}</td>
                <td class="whitespace-nowrap px-4 py-3">{cadence_label(schedule.interval_days)}</td>
                <td class="px-4 py-3">{schedule.open_assignment_count}</td>
                <td class="px-4 py-3">
                  <span class={[
                    "rounded px-2 py-0.5 text-xs font-medium",
                    schedule.active &&
                      "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
                    !schedule.active &&
                      "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-200"
                  ]}>
                    {if schedule.active, do: gettext("Active"), else: gettext("Paused")}
                  </span>
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/inspection-schedules/#{schedule.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={@can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={schedule.id}
                      data-confirm={gettext("Delete this schedule and its assignments?")}
                    >
                      {gettext("Delete")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@schedules == []}>
                <td colspan="6" class="px-4 py-6">
                  <.empty_state
                    icon="fa-calendar-days"
                    title={gettext("No schedules found")}
                    message={gettext("Schedule recurring inspections for your vehicles.")}
                  >
                    <.button
                      :if={@can_create}
                      navigate={~p"/o/#{org(assigns)}/inspection-schedules/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New schedule")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer id="schedule-filters">
        <.search_select
          id="filter_sched_vehicle_id"
          name="vehicle_id"
          value={@vehicle_id}
          label={gettext("Vehicle")}
          prompt={gettext("Any vehicle")}
          options={@vehicles}
        />
        <.search_select
          id="filter_sched_form_id"
          name="inspection_form_id"
          value={@form_id}
          label={gettext("Form")}
          prompt={gettext("Any form")}
          options={@forms}
        />
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Status")}</span>
          <div class="space-y-2">
            <label
              :for={{label, value} <- active_options()}
              class="flex items-center gap-2 text-sm text-body"
            >
              <input
                type="radio"
                name="active"
                value={value}
                checked={to_string(@active) == value}
                class="h-4 w-4 border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {label}
            </label>
          </div>
        </div>
      </.filter_drawer>
    </Layouts.app>
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
        sort_by(by, @sortable, :inserted_at)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    overrides = %{
      "vehicle_id" => nilify(params["vehicle_id"]),
      "inspection_form_id" => nilify(params["inspection_form_id"]),
      "active" => nilify(params["active"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/o/#{org(socket)}/inspection-schedules?#{prune(%{"q" => socket.assigns.query})}"
     )}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, schedule} <- Inspections.get_inspection_schedule(id, scope: scope),
         :ok <- Inspections.delete_inspection_schedule(schedule, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Schedule deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that schedule."))}
    end
  end

  defp index_path(socket, overrides) do
    params =
      %{
        "q" => socket.assigns.query,
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "vehicle_id" => socket.assigns.vehicle_id,
        "inspection_form_id" => socket.assigns.form_id,
        "active" => socket.assigns.active
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/inspection-schedules?#{params}"
  end

  defp filter_count(vehicle_id, form_id, active) do
    [vehicle_id, form_id, active] |> Enum.count(&(&1 not in [nil, ""]))
  end

  defp parse_active(v) when v in ["true", "false"], do: v
  defp parse_active(_), do: nil

  defp active_options do
    [{gettext("Any"), ""}, {gettext("Active"), "true"}, {gettext("Paused"), "false"}]
  end

  @doc false
  def cadence_label(1), do: gettext("Daily")
  def cadence_label(7), do: gettext("Weekly")
  def cadence_label(14), do: gettext("Every 2 weeks")
  def cadence_label(n), do: gettext("Every %{n} days", n: n)

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp form_options(scope) do
    case Inspections.list_inspection_forms(%{}, scope: scope, page: [limit: 200, offset: 0]) do
      {:ok, page} -> Enum.map(page.results, &{&1.title, &1.id})
      _ -> []
    end
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
