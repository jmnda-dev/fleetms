defmodule FleetmsWeb.VehicleLive.Index do
  @moduledoc """
  Lists an organization's vehicles with free-text search, a faceted filter
  drawer, sortable columns and pagination.

  All list state (search, filters, sort, page) lives in the URL query string, so
  every interaction is a `push_patch` and `handle_params` reloads — making views
  shareable and back/forward navigation work for free.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement
  alias FleetmsWeb.VehicleLive.StatusPresenter

  @limit 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Vehicles"),
       active_link: :vehicles,
       status_modal_vehicle: nil
     )}
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
      VehicleManagement.list_vehicles(
        %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
        scope: scope,
        load: [:tags, vehicle_model: [:vehicle_make]],
        page: [limit: @limit, offset: (page - 1) * @limit, count: true]
      )

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            vehicles: page_data.results,
            count: page_data.count || 0,
            page: page,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            makes:
              VehicleManagement.list_vehicle_makes!(scope: scope, query: [sort: [name: :asc]]),
            can_create: Scope.has_permission?(scope, :create_vehicle),
            can_update: Scope.has_permission?(scope, :update_vehicle),
            can_delete: Scope.has_permission?(scope, :delete_vehicle)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to vehicles here."))
          |> push_navigate(to: ~p"/o/#{org(socket)}")

        # Anything else is unexpected (e.g. an un-migrated tenant schema) — don't
        # mask it as an access problem; let it surface.
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
        %{label: gettext("Vehicles")}
      ]} />

      <.header>
        {gettext("Vehicles")}
        <:subtitle>{gettext("%{count} in this fleet", count: @count)}</:subtitle>
        <:actions>
          <.button
            :if={@can_create}
            variant="secondary"
            navigate={~p"/o/#{org(assigns)}/vehicles/import"}
          >
            <.icon name="fa-file-import" class="me-2" /> {gettext("Import")}
          </.button>
          <.button :if={@can_create} navigate={~p"/o/#{org(assigns)}/vehicles/new"}>
            <.icon name="fa-plus" class="me-2" /> {gettext("Add vehicle")}
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
                placeholder={gettext("Search name, make, model, plate, VIN…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>

          <div class="flex items-center gap-2">
            <.saved_views view_key="vehicles" />
            <button
              type="button"
              phx-hook="FilterDrawer"
              id="vehicle-filters-trigger"
              aria-controls="vehicle-filters"
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

        <%!-- Table --%>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 dark:bg-gray-700 text-xs uppercase text-heading">
              <tr>
                <.sort_th
                  label={gettext("Vehicle")}
                  field="name"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Make")}</th>
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Model")}</th>
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Type")}</th>
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                <.sort_th
                  label={gettext("Mileage")}
                  field="mileage"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Year")}
                  field="year"
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
                :for={vehicle <- @vehicles}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, vehicle)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  <div class="flex items-center gap-3">
                    <img
                      :if={thumbnail_url(vehicle)}
                      src={thumbnail_url(vehicle)}
                      alt=""
                      class="h-9 w-9 rounded-md object-cover"
                    />
                    <span
                      :if={is_nil(thumbnail_url(vehicle))}
                      class="flex h-9 w-9 items-center justify-center rounded-md bg-gray-100 text-gray-400 dark:bg-gray-700"
                    >
                      <.icon name="fa-truck" />
                    </span>
                    <div>
                      <span class="block">{vehicle.name}</span>
                      <.tag_list :if={vehicle.tags != []} tags={vehicle.tags} class="mt-1" />
                    </div>
                  </div>
                </th>
                <td phx-click={row_navigate(assigns, vehicle)} class="cursor-pointer px-4 py-3">
                  {make_name(vehicle)}
                </td>
                <td phx-click={row_navigate(assigns, vehicle)} class="cursor-pointer px-4 py-3">
                  {model_name(vehicle)}
                </td>
                <td phx-click={row_navigate(assigns, vehicle)} class="cursor-pointer px-4 py-3">
                  {vehicle.type}
                </td>
                <td class="px-4 py-3">
                  <button
                    :if={@can_update}
                    type="button"
                    phx-click="open_status"
                    phx-value-id={vehicle.id}
                    title={gettext("Change status")}
                  >
                    <StatusPresenter.status_badge status={vehicle.status} />
                  </button>
                  <span
                    :if={!@can_update}
                    phx-click={row_navigate(assigns, vehicle)}
                    class="cursor-pointer"
                  >
                    <StatusPresenter.status_badge status={vehicle.status} />
                  </span>
                </td>
                <td phx-click={row_navigate(assigns, vehicle)} class="cursor-pointer px-4 py-3">
                  {Format.distance(vehicle.mileage, org(assigns))}
                </td>
                <td phx-click={row_navigate(assigns, vehicle)} class="cursor-pointer px-4 py-3">
                  {vehicle.year || "—"}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      size="xs"
                      variant="ghost"
                      navigate={~p"/o/#{org(assigns)}/vehicles/#{vehicle.id}"}
                    >
                      {gettext("View")}
                    </.button>
                    <.button
                      :if={@can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/vehicles/#{vehicle.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={@can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={vehicle.id}
                      data-confirm={
                        gettext("Delete %{name}? This cannot be undone.", name: vehicle.name)
                      }
                    >
                      {gettext("Delete")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@vehicles == []}>
                <td colspan="8" class="px-4 py-6">
                  <.empty_state
                    icon="fa-truck"
                    title={gettext("No vehicles found")}
                    message={
                      gettext("Add a vehicle to start tracking your fleet, or adjust your search.")
                    }
                  >
                    <.button
                      :if={@can_create}
                      navigate={~p"/o/#{org(assigns)}/vehicles/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Add vehicle")}
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

      <.vehicle_filter_drawer
        makes={@makes}
        filters={@filters}
        status_options={StatusPresenter.filter_options()}
        type_options={type_options()}
        category_options={category_options()}
      />

      <StatusPresenter.status_modal vehicle={@status_modal_vehicle} />
    </Layouts.app>
    """
  end

  attr :makes, :list, required: true
  attr :filters, :map, required: true
  attr :status_options, :list, required: true
  attr :type_options, :list, required: true
  attr :category_options, :list, required: true

  defp vehicle_filter_drawer(assigns) do
    ~H"""
    <form
      id="vehicle-filters"
      phx-submit="apply-filters"
      tabindex="-1"
      aria-labelledby="vehicle-filters-label"
      class="fixed left-0 top-0 z-40 h-screen w-full max-w-sm -translate-x-full overflow-y-auto bg-white p-4 transition-transform dark:bg-gray-800"
    >
      <div class="flex items-center justify-between">
        <h5
          id="vehicle-filters-label"
          class="inline-flex items-center text-base font-semibold uppercase text-heading"
        >
          <.icon name="fa-filter" class="me-2" /> {gettext("Filters")}
        </h5>
        <button
          type="button"
          data-drawer-close
          aria-controls="vehicle-filters"
          class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-body hover:bg-gray-100 hover:text-heading dark:hover:bg-gray-700"
        >
          <.icon name="fa-xmark" />
          <span class="sr-only">{gettext("Close menu")}</span>
        </button>
      </div>

      <div class="mt-5 space-y-5">
        <.search_select
          id="filter_make_id"
          name="make_id"
          value={@filters["make_id"]}
          label={gettext("Make")}
          prompt={gettext("Any make")}
          options={Enum.map(@makes, &{&1.name, &1.id})}
        />

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
                checked={value in (@filters["statuses"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {label}
            </label>
          </div>
        </div>

        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Type")}</span>
          <div class="grid max-h-48 grid-cols-2 gap-2 overflow-y-auto">
            <label
              :for={{label, value} <- @type_options}
              class="flex items-center gap-2 text-sm text-body"
            >
              <input
                type="checkbox"
                name="type[]"
                value={value}
                checked={value in (@filters["types"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {label}
            </label>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <.input
            type="number"
            name="year_min"
            value={@filters["year_min"]}
            label={gettext("Year from")}
          />
          <.input
            type="number"
            name="year_max"
            value={@filters["year_max"]}
            label={gettext("Year to")}
          />
          <.input
            type="number"
            name="mileage_min"
            value={@filters["mileage_min"]}
            label={gettext("Mileage from")}
          />
          <.input
            type="number"
            name="mileage_max"
            value={@filters["mileage_max"]}
            label={gettext("Mileage to")}
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
    overrides =
      %{
        "make_id" => nilify(params["make_id"]),
        "status" => params["status"] || [],
        "type" => params["type"] || [],
        "category" => params["category"] || [],
        "year_min" => nilify(params["year_min"]),
        "year_max" => nilify(params["year_max"]),
        "mileage_min" => nilify(params["mileage_min"]),
        "mileage_max" => nilify(params["mileage_max"]),
        "page" => nil
      }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/o/#{org(socket)}/vehicles?#{%{"q" => socket.assigns.query}}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("open_status", %{"id" => id}, socket) do
    {:noreply,
     assign(socket, :status_modal_vehicle, Enum.find(socket.assigns.vehicles, &(&1.id == id)))}
  end

  def handle_event("close_status", _params, socket) do
    {:noreply, assign(socket, :status_modal_vehicle, nil)}
  end

  def handle_event("set_status", %{"id" => id, "status" => status}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, vehicle} <- VehicleManagement.get_vehicle(id, scope: scope),
         {:ok, _updated} <-
           VehicleManagement.update_vehicle_status(vehicle, %{status: status}, scope: scope) do
      {:noreply,
       socket
       |> assign(:status_modal_vehicle, nil)
       |> put_flash(:info, gettext("Status updated."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:status_modal_vehicle, nil)
         |> put_flash(:error, gettext("Could not update the status."))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, vehicle} <- VehicleManagement.get_vehicle(id, scope: scope),
         :ok <- VehicleManagement.delete_vehicle(vehicle, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Vehicle deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that vehicle."))}
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

    ~p"/o/#{org(socket)}/vehicles?#{params}"
  end

  defp current_params(assigns) do
    f = assigns.filters

    %{
      "q" => assigns.query,
      "sort" => to_string(assigns.sort_by),
      "dir" => to_string(assigns.sort_order),
      "page" => to_string(assigns.page),
      "make_id" => f["make_id"],
      "status" => f["statuses"] || [],
      "type" => f["types"] || [],
      "category" => f["categories"] || [],
      "year_min" => f["year_min"],
      "year_max" => f["year_max"],
      "mileage_min" => f["mileage_min"],
      "mileage_max" => f["mileage_max"]
    }
  end

  defp parse_filters(params) do
    %{
      "make_id" => nilify(params["make_id"]),
      "statuses" => List.wrap(params["status"]),
      "types" => List.wrap(params["type"]),
      "categories" => List.wrap(params["category"]),
      "year_min" => nilify(params["year_min"]),
      "year_max" => nilify(params["year_max"]),
      "mileage_min" => nilify(params["mileage_min"]),
      "mileage_max" => nilify(params["mileage_max"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  @sortable ~w(name year mileage status inserted_at)a
  defp sort_by(value) do
    Enum.find(@sortable, :name, &(to_string(&1) == value))
  end

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

  # --- display helpers ---

  defp total_pages(count), do: max(1, ceil(count / @limit))

  defp range_label(_count = 0, _page), do: "0"

  defp range_label(count, page) do
    from = (page - 1) * @limit + 1
    to = min(page * @limit, count)
    "#{from}–#{to}"
  end

  defp make_name(%{vehicle_model: %{vehicle_make: %{name: name}}}), do: name
  defp make_name(_), do: "—"

  defp model_name(%{vehicle_model: %{name: name}}), do: name
  defp model_name(_), do: "—"

  defp thumbnail_url(%{primary_thumbnail_key: key}) when is_binary(key),
    do: Fleetms.Storage.url(key)

  defp thumbnail_url(_), do: nil

  defp type_options,
    do: Enum.map(VehicleManagement.VehicleType.values(), &{to_string(&1), to_string(&1)})

  defp category_options,
    do: Enum.map(VehicleManagement.VehicleCategory.values(), &{to_string(&1), to_string(&1)})

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  # Navigate to a vehicle's detail page. Applied to the data cells (not the action
  # cell) so clicking anywhere on a row opens it, while the row's View/Edit/Delete
  # buttons keep their own behaviour.
  defp row_navigate(assigns, vehicle),
    do: JS.navigate(~p"/o/#{org(assigns)}/vehicles/#{vehicle.id}")
end
