defmodule FleetmsWeb.IssueLive.Index do
  @moduledoc """
  Lists an organization's issues with free-text search, a faceted filter drawer,
  sortable columns and pagination.

  Like the vehicle index, all list state (search, filters, sort, page) lives in
  the URL query string, so every interaction is a `push_patch` and `handle_params`
  reloads — making views shareable and back/forward navigation work for free.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Scope
  alias Fleetms.VehicleIssues
  alias Fleetms.VehicleManagement

  @limit 20
  @statuses [:open, :resolved, :closed]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Issues"), active_link: :issues)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    sort_by = sort_by(params["sort"])
    sort_order = sort_order(params["dir"])
    filters = parse_filters(params)
    page = page_number(params["page"])
    archived? = params["archived"] == "1"

    load = [:vehicle, :tags, assigned_to: [:email, profile: [:first_name, :last_name]]]

    result =
      if archived? do
        VehicleIssues.list_archived_issues(
          %{search_query: query, sort_by: sort_by, sort_order: sort_order},
          scope: scope,
          load: load,
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      else
        VehicleIssues.list_issues(
          %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
          scope: scope,
          load: load,
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      end

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            issues: page_data.results,
            count: page_data.count || 0,
            page: page,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            vehicles: vehicle_options(scope),
            # Selection resets on every list change (page/filter/sort) so a bulk
            # action never touches a row the user can no longer see.
            selected: MapSet.new(),
            can_create: Scope.has_permission?(scope, :create_issue),
            can_update: Scope.has_permission?(scope, :update_issue),
            can_delete: Scope.has_permission?(scope, :delete_issue)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to issues here."))
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
        %{label: gettext("Issues")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived issues"), else: gettext("Issues")}
        <:subtitle>
          {if @archived_view,
            do: gettext("%{count} archived", count: @count),
            else: gettext("%{count} reported", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/issues/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("Report issue")}
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
                placeholder={gettext("Search number, title, description…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>

          <div :if={not @archived_view} class="flex items-center gap-2">
            <.saved_views view_key="issues" />
            <button
              type="button"
              phx-hook="FilterDrawer"
              id="issue-filters-trigger"
              aria-controls="issue-filters"
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
        </div>

        <%!-- Bulk action bar: appears once one or more rows are selected --%>
        <div
          :if={bulk_enabled?(assigns) and MapSet.size(@selected) > 0}
          class="flex flex-wrap items-center gap-3 border-b border-default bg-primary-50 px-4 py-2.5 text-sm dark:bg-primary-900/20"
        >
          <span class="font-medium text-heading">
            {gettext("%{n} selected", n: MapSet.size(@selected))}
          </span>
          <.button
            :if={not @archived_view and @can_delete}
            size="xs"
            variant="danger"
            phx-click="bulk_archive"
            data-confirm={
              gettext("Archive %{n} selected issues? You can restore them later.",
                n: MapSet.size(@selected)
              )
            }
          >
            <.icon name="fa-box-archive" class="me-1 text-xs" /> {gettext("Archive")}
          </.button>
          <.button
            :if={@archived_view and @can_update}
            size="xs"
            variant="secondary"
            phx-click="bulk_restore"
          >
            <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
          </.button>
          <button
            type="button"
            phx-click="clear_selection"
            class="ms-auto text-xs font-medium text-body hover:text-heading hover:underline"
          >
            {gettext("Clear selection")}
          </button>
        </div>

        <%!-- Table --%>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 dark:bg-gray-700 text-xs uppercase text-heading">
              <tr>
                <th :if={bulk_enabled?(assigns)} scope="col" class="w-10 px-4 py-3">
                  <input
                    type="checkbox"
                    checked={all_selected?(assigns)}
                    phx-click="toggle_select_all"
                    aria-label={gettext("Select all")}
                    class="rounded border-default-medium text-brand focus:ring-brand"
                  />
                </th>
                <.sort_th
                  label={gettext("#")}
                  field="issue_number"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Title")}
                  field="title"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Assignee")}</th>
                <.sort_th
                  label={gettext("Priority")}
                  field="priority"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Status")}
                  field="status"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Reported")}
                  field="reported_at"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Due")}
                  field="due_date"
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
                :for={issue <- @issues}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <td :if={bulk_enabled?(assigns)} class="px-4 py-3">
                  <input
                    type="checkbox"
                    checked={MapSet.member?(@selected, issue.id)}
                    phx-click="toggle_select"
                    phx-value-id={issue.id}
                    aria-label={gettext("Select issue #%{n}", n: issue.issue_number)}
                    class="rounded border-default-medium text-brand focus:ring-brand"
                  />
                </td>
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, issue)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  #{issue.issue_number}
                </th>
                <td
                  phx-click={row_navigate(assigns, issue)}
                  class="max-w-xs cursor-pointer px-4 py-3 text-heading"
                >
                  <span class="block truncate">{issue.title}</span>
                  <.tag_list :if={issue.tags != []} tags={issue.tags} class="mt-1" />
                </td>
                <td phx-click={row_navigate(assigns, issue)} class="cursor-pointer px-4 py-3">
                  {vehicle_name(issue)}
                </td>
                <td phx-click={row_navigate(assigns, issue)} class="cursor-pointer px-4 py-3">
                  {assignee_name(issue)}
                </td>
                <td phx-click={row_navigate(assigns, issue)} class="cursor-pointer px-4 py-3">
                  <.badge color={priority_color(issue.priority)}>{issue.priority}</.badge>
                </td>
                <td phx-click={row_navigate(assigns, issue)} class="cursor-pointer px-4 py-3">
                  <.badge color={status_color(issue.status)}>{humanize_status(issue.status)}</.badge>
                </td>
                <td
                  phx-click={row_navigate(assigns, issue)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  {Format.date(issue.reported_at, org(assigns))}
                </td>
                <td
                  phx-click={row_navigate(assigns, issue)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  <span class={due_class(issue)}>{Format.date(issue.due_date, org(assigns))}</span>
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={issue.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={@archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="purge"
                      phx-value-id={issue.id}
                      data-confirm={
                        gettext(
                          "Permanently delete issue #%{n}? This can't be undone — its photos and documents are removed too.",
                          n: issue.issue_number
                        )
                      }
                    >
                      <.icon name="fa-trash" class="me-1 text-xs" /> {gettext("Delete permanently")}
                    </.button>
                    <.button
                      :if={not @archived_view}
                      size="xs"
                      variant="ghost"
                      navigate={~p"/o/#{org(assigns)}/issues/#{issue.id}"}
                    >
                      {gettext("View")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/issues/#{issue.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={issue.id}
                      data-confirm={
                        gettext("Archive issue #%{n}? You can restore it later from Show archived.",
                          n: issue.issue_number
                        )
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@issues == []}>
                <td colspan={if bulk_enabled?(assigns), do: "10", else: "9"} class="px-4 py-6">
                  <.empty_state
                    icon="fa-circle-exclamation"
                    title={
                      if @archived_view,
                        do: gettext("No archived issues"),
                        else: gettext("No issues yet")
                    }
                    message={
                      unless @archived_view, do: gettext("Report an issue to start tracking it.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/issues/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Report issue")}
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

      <.issue_filter_drawer
        vehicles={@vehicles}
        filters={@filters}
        status_options={status_options()}
        priority_options={priority_options()}
      />
    </Layouts.app>
    """
  end

  attr :vehicles, :list, required: true
  attr :filters, :map, required: true
  attr :status_options, :list, required: true
  attr :priority_options, :list, required: true

  defp issue_filter_drawer(assigns) do
    ~H"""
    <form
      id="issue-filters"
      phx-submit="apply-filters"
      tabindex="-1"
      aria-labelledby="issue-filters-label"
      class="fixed left-0 top-0 z-40 h-screen w-full max-w-sm -translate-x-full overflow-y-auto bg-white p-4 transition-transform dark:bg-gray-800"
    >
      <div class="flex items-center justify-between">
        <h5
          id="issue-filters-label"
          class="inline-flex items-center text-base font-semibold uppercase text-heading"
        >
          <.icon name="fa-filter" class="me-2" /> {gettext("Filters")}
        </h5>
        <button
          type="button"
          data-drawer-close
          aria-controls="issue-filters"
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
            <label
              :for={{label, value} <- @status_options}
              class="flex items-center gap-2 text-sm text-body"
            >
              <input
                type="checkbox"
                name="status[]"
                value={value}
                checked={value in Enum.map(@filters["statuses"] || [], &to_string/1)}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {label}
            </label>
          </div>
        </div>

        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Priority")}</span>
          <div class="space-y-2">
            <label
              :for={{label, value} <- @priority_options}
              class="flex items-center gap-2 text-sm text-body"
            >
              <input
                type="checkbox"
                name="priority[]"
                value={value}
                checked={value in Enum.map(@filters["priorities"] || [], &to_string/1)}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {label}
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

        <div class="grid grid-cols-2 gap-3">
          <.date_input
            id="filter_reported_from"
            name="reported_from"
            value={@filters["reported_from"]}
            label={gettext("Reported from")}
          />
          <.date_input
            id="filter_reported_to"
            name="reported_to"
            value={@filters["reported_to"]}
            label={gettext("Reported to")}
          />
          <.date_input
            id="filter_due_from"
            name="due_from"
            value={@filters["due_from"]}
            label={gettext("Due from")}
          />
          <.date_input
            id="filter_due_to"
            name="due_to"
            value={@filters["due_to"]}
            label={gettext("Due to")}
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
      "priority" => params["priority"] || [],
      "vehicle_id" => nilify(params["vehicle_id"]),
      "reported_from" => nilify(params["reported_from"]),
      "reported_to" => nilify(params["reported_to"]),
      "due_from" => nilify(params["due_from"]),
      "due_to" => nilify(params["due_to"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/o/#{org(socket)}/issues?#{%{"q" => socket.assigns.query}}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else: MapSet.put(selected, id)

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("toggle_select_all", _params, socket) do
    ids = Enum.map(socket.assigns.issues, & &1.id)

    selected =
      if all_selected?(socket.assigns), do: MapSet.new(), else: MapSet.new(ids)

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected, MapSet.new())}
  end

  def handle_event("bulk_archive", _params, socket) do
    {:noreply, bulk_apply(socket, &VehicleIssues.delete_issue/2, gettext("archived"))}
  end

  def handle_event("bulk_restore", _params, socket) do
    fun = fn issue, opts -> VehicleIssues.restore_issue(issue, %{}, opts) end
    {:noreply, bulk_apply(socket, fun, gettext("restored"))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, issue} <- VehicleIssues.get_issue(id, scope: scope),
         :ok <- VehicleIssues.delete_issue(issue, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Issue archived. Restore it any time from Show archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that issue."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, issue} <- VehicleIssues.get_issue(id, scope: scope),
         {:ok, _} <- VehicleIssues.restore_issue(issue, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Issue restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that issue."))}
    end
  end

  # Hard delete of an already-archived issue: removes the record and its stored files.
  def handle_event("purge", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, issue} <- VehicleIssues.get_issue(id, scope: scope),
         :ok <- VehicleIssues.purge_issue(issue, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Issue permanently deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that issue."))}
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

    ~p"/o/#{org(socket)}/issues?#{params}"
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/issues"
    else
      ~p"/o/#{org(assigns)}/issues?#{%{"archived" => "1"}}"
    end
  end

  defp current_params(assigns) do
    f = assigns.filters

    %{
      "q" => assigns.query,
      "sort" => to_string(assigns.sort_by),
      "dir" => to_string(assigns.sort_order),
      "page" => to_string(assigns.page),
      "archived" => if(assigns.archived_view, do: "1"),
      "status" => Enum.map(f["statuses"] || [], &to_string/1),
      "priority" => Enum.map(f["priorities"] || [], &to_string/1),
      "vehicle_id" => f["vehicle_id"],
      "reported_from" => f["reported_from"],
      "reported_to" => f["reported_to"],
      "due_from" => f["due_from"],
      "due_to" => f["due_to"]
    }
  end

  defp parse_filters(params) do
    %{
      "statuses" => atoms_in(params["status"], @statuses),
      "priorities" => atoms_in(params["priority"], priority_values()),
      "vehicle_id" => nilify(params["vehicle_id"]),
      "reported_from" => nilify(params["reported_from"]),
      "reported_to" => nilify(params["reported_to"]),
      "due_from" => nilify(params["due_from"]),
      "due_to" => nilify(params["due_to"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  # Map submitted strings to the known atom values, ignoring anything unrecognized
  # (so URL tampering can't inject arbitrary atoms).
  defp atoms_in(values, allowed) do
    submitted = List.wrap(values) |> MapSet.new()
    Enum.filter(allowed, &(to_string(&1) in submitted))
  end

  @sortable ~w(issue_number title priority status due_date reported_at)a
  defp sort_by(value), do: Enum.find(@sortable, :issue_number, &(to_string(&1) == value))

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
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  # --- display helpers ---

  defp total_pages(count), do: max(1, ceil(count / @limit))

  defp range_label(0, _page), do: "0"

  defp range_label(count, page) do
    from = (page - 1) * @limit + 1
    to = min(page * @limit, count)
    "#{from}–#{to}"
  end

  defp humanize_status(status), do: status |> to_string() |> String.capitalize()

  defp status_color(:open), do: "info"
  defp status_color(:resolved), do: "success"
  defp status_color(:closed), do: "gray"
  defp status_color(_), do: "gray"

  defp priority_color(:High), do: "danger"
  defp priority_color(:Medium), do: "warning"
  defp priority_color(:Low), do: "info"
  defp priority_color(_), do: "gray"

  defp vehicle_name(%{vehicle: %{name: name}}), do: name
  defp vehicle_name(_), do: "—"

  defp assignee_name(%{assigned_to: %_{} = user}), do: person_name(user)
  defp assignee_name(_), do: "—"

  # Build a display name from the loaded profile, falling back to the email.
  defp person_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp person_name(%{email: email}), do: to_string(email)

  # Highlight an overdue date on a still-open issue.
  defp due_class(%{due_date: %Date{} = due, status: :open}) do
    if Date.before?(due, Date.utc_today()), do: "font-medium text-fg-danger", else: ""
  end

  defp due_class(_), do: ""

  defp status_options, do: Enum.map(@statuses, &{humanize_status(&1), to_string(&1)})

  defp priority_options, do: Enum.map(priority_values(), &{to_string(&1), to_string(&1)})

  defp priority_values, do: Fleetms.VehicleIssues.IssuePriority.values()

  # Whether the checkbox column + bulk bar should show: there has to be a bulk
  # action the viewer can actually run in the current view.
  defp bulk_enabled?(%{archived_view: true} = assigns), do: assigns.can_update
  defp bulk_enabled?(assigns), do: assigns.can_delete

  # True only when there's at least one row and all of them are selected.
  defp all_selected?(%{issues: []}), do: false

  defp all_selected?(%{issues: issues, selected: selected}),
    do: Enum.all?(issues, &MapSet.member?(selected, &1.id))

  # Runs `fun` over every selected issue, reports how many succeeded, and reloads
  # the list (which clears the selection).
  defp bulk_apply(socket, fun, verb) do
    scope = socket.assigns.current_scope

    ok =
      socket.assigns.selected
      |> Enum.map(fn id ->
        case VehicleIssues.get_issue(id, scope: scope) do
          {:ok, issue} -> normalize_result(fun.(issue, scope: scope))
          _ -> :error
        end
      end)
      |> Enum.count(&(&1 == :ok))

    total = MapSet.size(socket.assigns.selected)

    socket
    |> put_flash(
      :info,
      if(ok == total,
        do: gettext("%{n} issues %{verb}.", n: ok, verb: verb),
        else: gettext("%{ok} of %{n} issues %{verb}.", ok: ok, n: total, verb: verb)
      )
    )
    |> push_patch(to: index_path(socket, %{}))
  end

  defp normalize_result(:ok), do: :ok
  defp normalize_result({:ok, _}), do: :ok
  defp normalize_result(_), do: :error

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  # Navigate to an issue's detail page. Applied to the data cells (not the action
  # cell) so clicking a row opens it while the row's buttons keep their behaviour.
  defp row_navigate(%{archived_view: true}, _issue), do: nil

  defp row_navigate(assigns, issue),
    do: JS.navigate(~p"/o/#{org(assigns)}/issues/#{issue.id}")
end
