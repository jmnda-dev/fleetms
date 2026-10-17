defmodule FleetmsWeb.AssignmentLive.Index do
  @moduledoc """
  Lists an organization's vehicle assignments with free-text search, a faceted
  filter drawer, sortable columns and pagination.

  Like the other index pages, all list state lives in the URL query string, so
  every interaction is a `push_patch` and `handle_params` reloads. Rows open the
  assignment for editing — there's no separate detail page for so simple a record.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  @limit 20
  @statuses ["Upcoming", "In-progress", "Past"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Assignments"), active_link: :assignments)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    sort_by = sort_by(params["sort"])
    sort_order = sort_order(params["dir"])
    filters = parse_filters(params)
    page = page_number(params["page"])

    result =
      VehicleManagement.list_vehicle_assignments(
        %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
        scope: scope,
        page: [limit: @limit, offset: (page - 1) * @limit, count: true]
      )

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            assignments: page_data.results,
            count: page_data.count || 0,
            page: page,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            vehicles: vehicle_options(scope),
            members: member_options(scope),
            can_create: Scope.has_permission?(scope, :create_assignment),
            can_update: Scope.has_permission?(scope, :update_assignment),
            can_delete: Scope.has_permission?(scope, :delete_assignment)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to assignments here."))
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
        %{label: gettext("Assignments")}
      ]} />

      <.header>
        {gettext("Assignments")}
        <:subtitle>{gettext("%{count} recorded", count: @count)}</:subtitle>
        <:actions>
          <.button :if={@can_create} navigate={~p"/o/#{org(assigns)}/assignments/new"}>
            <.icon name="fa-plus" class="me-2" /> {gettext("New assignment")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white dark:bg-gray-800 shadow-sm">
        <%!-- Toolbar: search + filter trigger --%>
        <div class="flex flex-col gap-3 border-b border-default p-4 md:flex-row md:items-center md:justify-between">
          <form phx-change="search" phx-submit="search" class="w-full md:max-w-sm">
            <div class="relative">
              <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                <.icon name="fa-magnifying-glass" class="text-body text-sm" />
              </div>
              <input
                type="search"
                name="q"
                value={@query}
                phx-debounce="300"
                placeholder={gettext("Search vehicle, assignee, comments…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>

          <button
            type="button"
            phx-hook="FilterDrawer"
            id="assignment-filters-trigger"
            aria-controls="assignment-filters"
            class="inline-flex items-center justify-center gap-2 rounded-base border border-default-medium bg-white px-4 py-2 text-sm font-medium text-heading hover:bg-gray-50 dark:bg-gray-800 dark:hover:bg-gray-700"
          >
            <.icon name="fa-filter" class="text-body text-sm" />
            {gettext("Filters")}
            <span
              :if={map_size(@filters) > 0}
              class="ml-1 rounded-full bg-brand px-2 py-0.5 text-xs font-semibold text-white"
            >
              {map_size(@filters)}
            </span>
          </button>
        </div>

        <%!-- Table --%>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 dark:bg-gray-700 text-xs uppercase text-heading">
              <tr>
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Assignee")}</th>
                <.sort_th
                  label={gettext("Status")}
                  field="status"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Start")}
                  field="start_datetime"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("End")}
                  field="end_datetime"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th scope="col" class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={assignment <- @assignments}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, assignment)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {vehicle_name(assignment)}
                </th>
                <td phx-click={row_navigate(assigns, assignment)} class="cursor-pointer px-4 py-3">
                  {assignee_name(assignment)}
                </td>
                <td phx-click={row_navigate(assigns, assignment)} class="cursor-pointer px-4 py-3">
                  <.badge color={status_color(assignment.status)}>{assignment.status}</.badge>
                </td>
                <td
                  phx-click={row_navigate(assigns, assignment)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  {Format.datetime(assignment.start_datetime, org(assigns))}
                </td>
                <td
                  phx-click={row_navigate(assigns, assignment)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  {Format.datetime(assignment.end_datetime, org(assigns))}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/assignments/#{assignment.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={@can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={assignment.id}
                      data-confirm={gettext("Delete this assignment? This cannot be undone.")}
                    >
                      {gettext("Delete")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@assignments == []}>
                <td colspan="6" class="px-4 py-6">
                  <.empty_state
                    icon="fa-user-check"
                    title={gettext("No assignments yet")}
                    message={gettext("Assign a vehicle to a driver to track who's using what.")}
                  >
                    <.button
                      :if={@can_create}
                      navigate={~p"/o/#{org(assigns)}/assignments/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New assignment")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Pagination --%>
        <div
          :if={@count > 0}
          class="flex flex-col items-center justify-between gap-3 border-t border-default p-4 sm:flex-row"
        >
          <span class="text-sm text-body">
            {gettext("Showing %{range} of %{count}", range: range_label(@count, @page), count: @count)}
          </span>
          <div class="flex items-center gap-2">
            <.button
              size="sm"
              variant="secondary"
              disabled={@page <= 1}
              phx-click="paginate"
              phx-value-page={@page - 1}
            >
              <.icon name="fa-chevron-left" class="text-xs" /> {gettext("Previous")}
            </.button>
            <span class="text-sm text-body">
              {gettext("Page %{page} of %{total}", page: @page, total: total_pages(@count))}
            </span>
            <.button
              size="sm"
              variant="secondary"
              disabled={@page >= total_pages(@count)}
              phx-click="paginate"
              phx-value-page={@page + 1}
            >
              {gettext("Next")} <.icon name="fa-chevron-right" class="text-xs" />
            </.button>
          </div>
        </div>
      </div>

      <.assignment_filter_drawer
        vehicles={@vehicles}
        members={@members}
        filters={@filters}
        status_options={statuses()}
      />
    </Layouts.app>
    """
  end

  attr :vehicles, :list, required: true
  attr :members, :list, required: true
  attr :filters, :map, required: true
  attr :status_options, :list, required: true

  defp assignment_filter_drawer(assigns) do
    ~H"""
    <form
      id="assignment-filters"
      phx-submit="apply-filters"
      tabindex="-1"
      aria-labelledby="assignment-filters-label"
      class="fixed left-0 top-0 z-40 h-screen w-full max-w-sm -translate-x-full overflow-y-auto bg-white p-4 transition-transform dark:bg-gray-800"
    >
      <div class="flex items-center justify-between">
        <h5
          id="assignment-filters-label"
          class="inline-flex items-center text-base font-semibold uppercase text-heading"
        >
          <.icon name="fa-filter" class="me-2" /> {gettext("Filters")}
        </h5>
        <button
          type="button"
          data-drawer-close
          aria-controls="assignment-filters"
          class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-body hover:bg-gray-100 hover:text-heading dark:hover:bg-gray-700"
        >
          <.icon name="fa-xmark" />
          <span class="sr-only">{gettext("Close menu")}</span>
        </button>
      </div>

      <div class="mt-5 space-y-5">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Status")}</span>
          <div class="space-y-2">
            <label :for={status <- @status_options} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="status[]"
                value={status}
                checked={status in (@filters["statuses"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {status}
            </label>
          </div>
        </div>

        <.search_select
          id="filter_vehicle_id"
          name="vehicle_id"
          value={@filters["vehicle_id"]}
          label={gettext("Vehicle")}
          prompt={gettext("Any vehicle")}
          options={@vehicles}
        />
        <.search_select
          id="filter_assignee_id"
          name="assignee_id"
          value={@filters["assignee_id"]}
          label={gettext("Assignee")}
          prompt={gettext("Anyone")}
          options={@members}
        />

        <div class="grid grid-cols-2 gap-3">
          <.date_input
            id="filter_start_from"
            name="start_from"
            value={@filters["start_from"]}
            label={gettext("Start from")}
          />
          <.date_input
            id="filter_start_to"
            name="start_to"
            value={@filters["start_to"]}
            label={gettext("Start to")}
          />
        </div>

        <div class="flex gap-3 pt-2">
          <.button type="submit" class="w-full" data-drawer-close>
            {gettext("Apply filters")}
          </.button>
          <.button
            type="button"
            variant="secondary"
            class="w-full"
            phx-click="clear-filters"
            data-drawer-close
          >
            {gettext("Clear all")}
          </.button>
        </div>
      </div>
    </form>
    """
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"q" => nilify(q), "page" => nil}))}
  end

  def handle_event("sort", %{"by" => by}, socket) do
    {sort, dir} = next_sort(socket.assigns, by)
    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    overrides = %{
      "status" => params["status"] || [],
      "vehicle_id" => nilify(params["vehicle_id"]),
      "assignee_id" => nilify(params["assignee_id"]),
      "start_from" => nilify(params["start_from"]),
      "start_to" => nilify(params["start_to"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/o/#{org(socket)}/assignments?#{%{"q" => socket.assigns.query}}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, assignment} <- VehicleManagement.get_vehicle_assignment(id, scope: scope),
         :ok <- VehicleManagement.delete_vehicle_assignment(assignment, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Assignment deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that assignment."))}
    end
  end

  # --- URL <-> state ---

  defp index_path(socket, overrides) do
    params =
      socket.assigns
      |> current_params()
      |> Map.merge(overrides)
      |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
      |> Map.new()

    ~p"/o/#{org(socket)}/assignments?#{params}"
  end

  defp current_params(assigns) do
    f = assigns.filters

    %{
      "q" => assigns.query,
      "sort" => to_string(assigns.sort_by),
      "dir" => to_string(assigns.sort_order),
      "page" => to_string(assigns.page),
      "status" => f["statuses"] || [],
      "vehicle_id" => f["vehicle_id"],
      "assignee_id" => f["assignee_id"],
      "start_from" => f["start_from"],
      "start_to" => f["start_to"]
    }
  end

  defp parse_filters(params) do
    %{
      "statuses" => Enum.filter(List.wrap(params["status"]), &(&1 in @statuses)),
      "vehicle_id" => nilify(params["vehicle_id"]),
      "assignee_id" => nilify(params["assignee_id"]),
      "start_from" => nilify(params["start_from"]),
      "start_to" => nilify(params["start_to"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  @sortable ~w(start_datetime end_datetime status inserted_at)a
  defp sort_by(value), do: Enum.find(@sortable, :start_datetime, &(to_string(&1) == value))

  defp sort_order("asc"), do: :asc
  defp sort_order(_), do: :desc

  defp next_sort(%{sort_by: current, sort_order: order}, by) do
    by_atom = sort_by(by)

    cond do
      by_atom != current -> {to_string(by_atom), "asc"}
      order == :asc -> {to_string(by_atom), "desc"}
      true -> {to_string(by_atom), "asc"}
    end
  end

  defp page_number(value) do
    case Integer.parse(to_string(value)) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp nilify(nil), do: nil
  defp nilify(""), do: nil
  defp nilify(value), do: value

  # --- data ---

  defp vehicle_options(scope) do
    case VehicleManagement.list_assignable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp member_options(scope) do
    Fleetms.Accounts.list_user_organizations!(
      scope: scope,
      query: [filter: [organization_id: scope.organization.id, status: :active]],
      load: [user: [:email, profile: [:first_name, :last_name]]]
    )
    |> Enum.map(fn membership -> {person_name(membership.user), membership.user_id} end)
  end

  # --- display helpers ---

  defp total_pages(count), do: max(1, ceil(count / @limit))

  defp range_label(0, _page), do: "0"

  defp range_label(count, page) do
    from = (page - 1) * @limit + 1
    to = min(page * @limit, count)
    "#{from}–#{to}"
  end

  defp statuses, do: @statuses

  defp status_color("Upcoming"), do: "info"
  defp status_color("In-progress"), do: "success"
  defp status_color("Past"), do: "gray"
  defp status_color(_), do: "gray"

  defp vehicle_name(%{vehicle: %{name: name}}), do: name
  defp vehicle_name(_), do: "—"

  defp assignee_name(%{assignee: %_{} = user}), do: person_name(user)
  defp assignee_name(%{driver: %_{} = driver}), do: person_name(driver)
  defp assignee_name(_), do: "—"

  defp person_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  # A driver carries its name directly (no linked profile).
  defp person_name(%{first_name: first, last_name: last}) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> "—"
      name -> name
    end
  end

  defp person_name(%{email: email}), do: to_string(email)
  defp person_name(_), do: "—"

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  # Open an assignment for editing (no separate detail page for so simple a record).
  defp row_navigate(assigns, assignment),
    do: JS.navigate(~p"/o/#{org(assigns)}/assignments/#{assignment.id}/edit")
end
