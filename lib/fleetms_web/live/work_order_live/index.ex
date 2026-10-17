defmodule FleetmsWeb.WorkOrderLive.Index do
  @moduledoc """
  Lists an organization's work orders with free-text search, a faceted filter
  drawer (status, category, vehicle, assignee, issued-date range), sortable columns
  and pagination. An archived view with restore / permanent-delete is reachable from
  the header. All list state lives in the URL query string.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Format
  alias Fleetms.Maintenance
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  @limit 20
  @sortable ~w(work_order_number issued_at status completed_at)a
  @statuses ~w(open in_progress completed)
  @categories ~w(preventive corrective emergency scheduled)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Work Orders"), active_link: :maintenance)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    archived? = params["archived"] == "1"
    sort_by = sort_by(params["sort"], @sortable, :work_order_number)
    sort_order = sort_order_default(params["dir"])
    filters = parse_filters(params)
    page = page_number(params["page"])

    args = %{
      search_query: query,
      filters: filters,
      sort_by: sort_by,
      sort_order: sort_order
    }

    opts = [
      scope: scope,
      load: [:tags],
      page: [limit: @limit, offset: (page - 1) * @limit, count: true]
    ]

    result =
      if archived? do
        Maintenance.list_archived_work_orders(args, opts)
      else
        Maintenance.list_work_orders(args, opts)
      end

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            work_orders: page_data.results,
            count: page_data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            statuses: @statuses,
            categories: @categories,
            vehicles: vehicle_options(scope),
            members: member_options(scope),
            can_create: Scope.has_permission?(scope, :create_work_order),
            can_update: Scope.has_permission?(scope, :update_work_order),
            can_delete: Scope.has_permission?(scope, :delete_work_order)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to work orders here."))
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
        %{label: gettext("Work Orders")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived work orders"), else: gettext("Work Orders")}
        <:subtitle>
          {if @archived_view,
            do: gettext("Archived work orders can be restored."),
            else: gettext("%{count} maintenance jobs and what they cost.", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/work-orders/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New work order")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          query={@query}
          filter_count={map_size(@filters)}
          drawer_id="work-order-filters"
          placeholder={gettext("Search by number, vehicle…")}
        />

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <.sort_th
                  label={gettext("#")}
                  field="work_order_number"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <.sort_th
                  label={gettext("Status")}
                  field="status"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Tasks")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Assigned to")}</th>
                <.sort_th
                  label={gettext("Issued")}
                  field="issued_at"
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
                :for={wo <- @work_orders}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, wo)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  #{wo.work_order_number}
                </th>
                <td phx-click={row_navigate(assigns, wo)} class="cursor-pointer px-4 py-3">
                  {wo.vehicle.name}
                  <.tag_list :if={wo.tags != []} tags={wo.tags} class="mt-1" />
                </td>
                <td phx-click={row_navigate(assigns, wo)} class="cursor-pointer px-4 py-3">
                  <.status_badge status={wo.status} />
                </td>
                <td phx-click={row_navigate(assigns, wo)} class="cursor-pointer px-4 py-3">
                  {wo.service_task_count}
                </td>
                <td phx-click={row_navigate(assigns, wo)} class="cursor-pointer px-4 py-3">
                  {assignee_name(wo)}
                </td>
                <td phx-click={row_navigate(assigns, wo)} class="cursor-pointer px-4 py-3">
                  {Format.date(wo.issued_at, org(assigns))}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={wo.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={@archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="purge"
                      phx-value-id={wo.id}
                      data-confirm={
                        gettext(
                          "Permanently delete work order #%{n}? This can't be undone — its photos and documents are removed too.",
                          n: wo.work_order_number
                        )
                      }
                    >
                      <.icon name="fa-trash" class="me-1 text-xs" /> {gettext("Delete permanently")}
                    </.button>
                    <.button
                      :if={not @archived_view}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/work-orders/#{wo.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={wo.id}
                      data-confirm={
                        gettext(
                          "Archive this work order? You can restore it later from Show archived."
                        )
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@work_orders == []}>
                <td colspan="7" class="px-4 py-6">
                  <.empty_state
                    icon="fa-screwdriver-wrench"
                    title={
                      if @archived_view,
                        do: gettext("No archived work orders"),
                        else: gettext("No work orders found")
                    }
                    message={
                      unless @archived_view, do: gettext("Create a work order to record maintenance.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/work-orders/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New work order")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer id="work-order-filters">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Status")}</span>
          <div class="space-y-2">
            <label :for={st <- @statuses} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="status[]"
                value={st}
                checked={st in (@filters["statuses"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {status_label(st)}
            </label>
          </div>
        </div>

        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Category")}</span>
          <div class="space-y-2">
            <label :for={cat <- @categories} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="repair_category[]"
                value={cat}
                checked={cat in (@filters["categories"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {String.capitalize(cat)}
            </label>
          </div>
        </div>

        <.search_select
          id="filter_wo_vehicle_id"
          name="vehicle_id"
          value={@filters["vehicle_id"]}
          label={gettext("Vehicle")}
          prompt={gettext("Any vehicle")}
          options={@vehicles}
        />
        <.search_select
          id="filter_wo_assigned_to_id"
          name="assigned_to_id"
          value={@filters["assigned_to_id"]}
          label={gettext("Assigned to")}
          prompt={gettext("Anyone")}
          options={@members}
        />

        <div class="grid grid-cols-2 gap-3">
          <.date_input
            id="filter_wo_issued_from"
            name="issued_from"
            value={@filters["issued_from"]}
            label={gettext("Issued from")}
          />
          <.date_input
            id="filter_wo_issued_to"
            name="issued_to"
            value={@filters["issued_to"]}
            label={gettext("Issued to")}
          />
        </div>
      </.filter_drawer>
    </Layouts.app>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    {label, classes} =
      case assigns.status do
        :open ->
          {gettext("Open"), "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"}

        :in_progress ->
          {gettext("In progress"),
           "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"}

        :completed ->
          {gettext("Completed"),
           "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"}
      end

    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={[
      "inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-medium",
      @classes
    ]}>
      {@label}
    </span>
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
        sort_by(by, @sortable, :work_order_number)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    overrides = %{
      "status" => params["status"] || [],
      "repair_category" => params["repair_category"] || [],
      "vehicle_id" => nilify(params["vehicle_id"]),
      "assigned_to_id" => nilify(params["assigned_to_id"]),
      "issued_from" => nilify(params["issued_from"]),
      "issued_to" => nilify(params["issued_to"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    base = %{"q" => socket.assigns.query, "archived" => archived_param(socket)}
    {:noreply, push_patch(socket, to: ~p"/o/#{org(socket)}/work-orders?#{prune(base)}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, wo} <- Maintenance.get_work_order(id, scope: scope),
         :ok <- Maintenance.delete_work_order(wo, scope: scope) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext("Work order archived. Restore it any time from Show archived.")
       )
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that work order."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, wo} <- Maintenance.get_work_order(id, scope: scope),
         {:ok, _} <- Maintenance.restore_work_order(wo, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Work order restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that work order."))}
    end
  end

  # Hard delete of an already-archived work order: removes the record and its stored files.
  def handle_event("purge", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, wo} <- Maintenance.get_work_order(id, scope: scope),
         :ok <- Maintenance.purge_work_order(wo, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Work order permanently deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that work order."))}
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
        "status" => f["statuses"] || [],
        "repair_category" => f["categories"] || [],
        "vehicle_id" => f["vehicle_id"],
        "assigned_to_id" => f["assigned_to_id"],
        "issued_from" => f["issued_from"],
        "issued_to" => f["issued_to"]
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/work-orders?#{params}"
  end

  defp archived_param(socket), do: if(socket.assigns.archived_view, do: "1")

  defp parse_filters(params) do
    %{
      "statuses" => Enum.filter(List.wrap(params["status"]), &(&1 in @statuses)),
      "categories" => Enum.filter(List.wrap(params["repair_category"]), &(&1 in @categories)),
      "vehicle_id" => nilify(params["vehicle_id"]),
      "assigned_to_id" => nilify(params["assigned_to_id"]),
      "issued_from" => nilify(params["issued_from"]),
      "issued_to" => nilify(params["issued_to"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/work-orders"
    else
      ~p"/o/#{org(assigns)}/work-orders?#{%{"archived" => "1"}}"
    end
  end

  defp status_label("open"), do: gettext("Open")
  defp status_label("in_progress"), do: gettext("In progress")
  defp status_label("completed"), do: gettext("Completed")
  defp status_label(other), do: other

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
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

  defp person_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp person_name(%{email: email}), do: to_string(email)
  defp person_name(_), do: "—"

  defp assignee_name(%{assigned_to: %{profile: %{first_name: first, last_name: last}}}) do
    case String.trim("#{first} #{last}") do
      "" -> "—"
      name -> name
    end
  end

  defp assignee_name(_), do: "—"

  # list_archived defaults to a descending number sort; the active list defaults
  # the same way, so an unset direction becomes :desc.
  defp sort_order_default(nil), do: :desc
  defp sort_order_default(value), do: sort_order(value)

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(%{archived_view: true}, _wo), do: nil

  defp row_navigate(assigns, wo),
    do: JS.navigate(~p"/o/#{org(assigns)}/work-orders/#{wo.id}")
end
