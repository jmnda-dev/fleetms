defmodule FleetmsWeb.RenewalLive.Index do
  @moduledoc """
  Lists an organization's vehicle renewals (insurance, roadworthiness, …) with
  search, a faceted filter drawer, sortable columns and pagination.

  All list state lives in the URL query string. Rows open the renewal for editing;
  recurring renewals also offer a one-click "Renew" that rolls the due date
  forward a cycle.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  @limit 20
  @statuses ["Upcoming", "Due Soon", "Overdue"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Renewals"), active_link: :renewals)}
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

    result =
      if archived? do
        VehicleManagement.list_archived_vehicle_renewals(
          %{search_query: query, sort_by: sort_by, sort_order: sort_order},
          scope: scope,
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      else
        VehicleManagement.list_vehicle_renewals(
          %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
          scope: scope,
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      end

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            renewals: page_data.results,
            count: page_data.count || 0,
            page: page,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            vehicles: vehicle_options(scope),
            types: type_options(scope),
            can_create: Scope.has_permission?(scope, :create_renewal),
            can_update: Scope.has_permission?(scope, :update_renewal),
            can_delete: Scope.has_permission?(scope, :delete_renewal)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to renewals here."))
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
        %{label: gettext("Renewals")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived renewals"), else: gettext("Renewals")}
        <:subtitle>
          {if @archived_view,
            do: gettext("%{count} archived", count: @count),
            else: gettext("%{count} tracked", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/renewals/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New renewal")}
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
                placeholder={gettext("Search vehicle, type, comments…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>

          <button
            :if={not @archived_view}
            type="button"
            phx-hook="FilterDrawer"
            id="renewal-filters-trigger"
            aria-controls="renewal-filters"
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
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Type")}</th>
                <.sort_th
                  label={gettext("Due")}
                  field="due_date"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Status")}
                  field="status"
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
                :for={renewal <- @renewals}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, renewal)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {vehicle_name(renewal)}
                </th>
                <td phx-click={row_navigate(assigns, renewal)} class="cursor-pointer px-4 py-3">
                  {type_name(renewal)}
                </td>
                <td
                  phx-click={row_navigate(assigns, renewal)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  {Format.date(renewal.due_date, org(assigns))}
                </td>
                <td phx-click={row_navigate(assigns, renewal)} class="cursor-pointer px-4 py-3">
                  <.badge color={status_color(renewal.status)}>{renewal.status}</.badge>
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={renewal.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update and recurring?(renewal)}
                      size="xs"
                      variant="success"
                      phx-click="mark-renewed"
                      phx-value-id={renewal.id}
                      data-confirm={gettext("Mark as renewed and roll the due date forward?")}
                    >
                      {gettext("Renew")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/renewals/#{renewal.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={renewal.id}
                      data-confirm={
                        gettext("Archive this renewal? You can restore it later from Show archived.")
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@renewals == []}>
                <td colspan="5" class="px-4 py-6">
                  <.empty_state
                    icon="fa-file-contract"
                    title={
                      if @archived_view,
                        do: gettext("No archived renewals"),
                        else: gettext("No renewals yet")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Track insurance, road tax and other renewals before they lapse.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/renewals/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Add renewal")}
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

      <.renewal_filter_drawer
        vehicles={@vehicles}
        types={@types}
        filters={@filters}
        status_options={statuses()}
      />
    </Layouts.app>
    """
  end

  attr :vehicles, :list, required: true
  attr :types, :list, required: true
  attr :filters, :map, required: true
  attr :status_options, :list, required: true

  defp renewal_filter_drawer(assigns) do
    ~H"""
    <form
      id="renewal-filters"
      phx-submit="apply-filters"
      tabindex="-1"
      aria-labelledby="renewal-filters-label"
      class="fixed left-0 top-0 z-40 h-screen w-full max-w-sm -translate-x-full overflow-y-auto bg-white p-4 transition-transform dark:bg-gray-800"
    >
      <div class="flex items-center justify-between">
        <h5
          id="renewal-filters-label"
          class="inline-flex items-center text-base font-semibold uppercase text-heading"
        >
          <.icon name="fa-filter" class="me-2" /> {gettext("Filters")}
        </h5>
        <button
          type="button"
          data-drawer-close
          aria-controls="renewal-filters"
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
          id="filter_renewal_type_id"
          name="renewal_type_id"
          value={@filters["renewal_type_id"]}
          label={gettext("Type")}
          prompt={gettext("Any type")}
          options={@types}
        />

        <div class="grid grid-cols-2 gap-3">
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
      "vehicle_id" => nilify(params["vehicle_id"]),
      "renewal_type_id" => nilify(params["renewal_type_id"]),
      "due_from" => nilify(params["due_from"]),
      "due_to" => nilify(params["due_to"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/o/#{org(socket)}/renewals?#{%{"q" => socket.assigns.query}}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("mark-renewed", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, renewal} <- VehicleManagement.get_vehicle_renewal(id, scope: scope),
         {:ok, _} <- VehicleManagement.mark_renewal_completed(renewal, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Renewal rolled forward."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not update that renewal."))}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, renewal} <- VehicleManagement.get_vehicle_renewal(id, scope: scope),
         :ok <- VehicleManagement.delete_vehicle_renewal(renewal, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Renewal archived. Restore it any time from Show archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that renewal."))}
    end
  end

  # Archived renewals are hidden from `get_vehicle_renewal`, so restore the record we
  # already loaded into the archived list rather than looking it up.
  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with renewal when not is_nil(renewal) <-
           Enum.find(socket.assigns.renewals, &(&1.id == id)),
         {:ok, _} <- VehicleManagement.restore_vehicle_renewal(renewal, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Renewal restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that renewal."))}
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

    ~p"/o/#{org(socket)}/renewals?#{params}"
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/renewals"
    else
      ~p"/o/#{org(assigns)}/renewals?#{%{"archived" => "1"}}"
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
      "status" => f["statuses"] || [],
      "vehicle_id" => f["vehicle_id"],
      "renewal_type_id" => f["renewal_type_id"],
      "due_from" => f["due_from"],
      "due_to" => f["due_to"]
    }
  end

  defp parse_filters(params) do
    %{
      "statuses" => Enum.filter(List.wrap(params["status"]), &(&1 in @statuses)),
      "vehicle_id" => nilify(params["vehicle_id"]),
      "renewal_type_id" => nilify(params["renewal_type_id"]),
      "due_from" => nilify(params["due_from"]),
      "due_to" => nilify(params["due_to"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  @sortable ~w(due_date status inserted_at)a
  defp sort_by(value), do: Enum.find(@sortable, :due_date, &(to_string(&1) == value))

  defp sort_order("desc"), do: :desc
  defp sort_order(_), do: :asc

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

  defp type_options(scope) do
    VehicleManagement.list_renewal_types!(scope: scope, query: [sort: [name: :asc]])
    |> Enum.map(&{&1.name, &1.id})
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
  defp status_color("Due Soon"), do: "warning"
  defp status_color("Overdue"), do: "danger"
  defp status_color(_), do: "gray"

  defp recurring?(%{recurrence_interval: amount, recurrence_unit: unit}),
    do: not is_nil(amount) and not is_nil(unit)

  defp vehicle_name(%{vehicle: %{name: name}}), do: name
  defp vehicle_name(_), do: "—"

  defp type_name(%{renewal_type: %{name: name}}), do: name
  defp type_name(_), do: "—"

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(%{archived_view: true}, _renewal), do: nil

  defp row_navigate(assigns, renewal),
    do: JS.navigate(~p"/o/#{org(assigns)}/renewals/#{renewal.id}/edit")
end
