defmodule FleetmsWeb.FuelLive.Index do
  @moduledoc """
  Lists an organization's fuel entries with search, a faceted filter drawer,
  sortable columns and pagination.

  All list state lives in the URL query string. Rows open the entry for editing.
  Each entry's cost is shown in its own currency.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.FuelManagement
  alias Fleetms.Scope

  @limit 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Fuel"), active_link: :fuel)}
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
        FuelManagement.list_archived_fuel_entries(
          %{search_query: query, sort_by: sort_by, sort_order: sort_order},
          scope: scope,
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      else
        FuelManagement.list_fuel_entries(
          %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
          scope: scope,
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      end

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            entries: page_data.results,
            count: page_data.count || 0,
            page: page,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            vehicles: vehicle_options(scope),
            can_create: Scope.has_permission?(scope, :create_fuel_entry),
            can_update: Scope.has_permission?(scope, :update_fuel_entry),
            can_delete: Scope.has_permission?(scope, :delete_fuel_entry)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to fuel entries here."))
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
        %{label: gettext("Fuel")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived fuel entries"), else: gettext("Fuel")}
        <:subtitle>
          {if @archived_view,
            do: gettext("%{count} archived", count: @count),
            else: gettext("%{count} entries", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/fuel/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New fuel entry")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
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
                placeholder={gettext("Search vehicle, location, notes…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>

          <div :if={not @archived_view} class="flex items-center gap-2">
            <.saved_views view_key="fuel" />
            <button
              type="button"
              phx-hook="FilterDrawer"
              id="fuel-filters-trigger"
              aria-controls="fuel-filters"
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
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <.sort_th
                  label={gettext("Date")}
                  field="refueled_at"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th scope="col" class="px-4 py-3 font-semibold">{gettext("Fuel")}</th>
                <.sort_th
                  label={gettext("Odometer")}
                  field="odometer"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Quantity")}
                  field="quantity"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th scope="col" class="px-4 py-3 text-right font-semibold">{gettext("Cost")}</th>
                <th scope="col" class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={entry <- @entries}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, entry)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {Format.date(entry.refueled_at, org(assigns))}
                </th>
                <td phx-click={row_navigate(assigns, entry)} class="cursor-pointer px-4 py-3">
                  {vehicle_name(entry)}
                </td>
                <td phx-click={row_navigate(assigns, entry)} class="cursor-pointer px-4 py-3">
                  {humanize(entry.fuel_type)}
                </td>
                <td
                  phx-click={row_navigate(assigns, entry)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  {Format.distance(entry.odometer, org(assigns))}
                </td>
                <td
                  phx-click={row_navigate(assigns, entry)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  {Format.volume(entry.quantity, org(assigns))}
                </td>
                <td
                  phx-click={row_navigate(assigns, entry)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 text-right font-medium text-heading"
                >
                  <.icon
                    :if={entry.receipt_image_key}
                    name="fa-receipt"
                    class="me-1 text-xs text-gray-400"
                    title={gettext("Receipt attached")}
                  />
                  {fmt_money(entry.cost)}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={entry.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/fuel/#{entry.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={entry.id}
                      data-confirm={
                        gettext(
                          "Archive this fuel entry? You can restore it later from Show archived."
                        )
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@entries == []}>
                <td colspan="7" class="px-4 py-6">
                  <.empty_state
                    icon="fa-gas-pump"
                    title={
                      if @archived_view,
                        do: gettext("No archived fuel entries"),
                        else: gettext("No fuel entries yet")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Log a fill-up to start tracking fuel and economy.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/fuel/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Log fuel")}
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

      <.fuel_filter_drawer vehicles={@vehicles} filters={@filters} />
    </Layouts.app>
    """
  end

  attr :vehicles, :list, required: true
  attr :filters, :map, required: true

  defp fuel_filter_drawer(assigns) do
    ~H"""
    <form
      id="fuel-filters"
      phx-submit="apply-filters"
      tabindex="-1"
      aria-labelledby="fuel-filters-label"
      class="fixed left-0 top-0 z-40 h-screen w-full max-w-sm -translate-x-full overflow-y-auto bg-white p-4 transition-transform dark:bg-gray-800"
    >
      <div class="flex items-center justify-between">
        <h5
          id="fuel-filters-label"
          class="inline-flex items-center text-base font-semibold uppercase text-heading"
        >
          <.icon name="fa-filter" class="me-2" /> {gettext("Filters")}
        </h5>
        <button
          type="button"
          data-drawer-close
          aria-controls="fuel-filters"
          class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-body hover:bg-gray-100 hover:text-heading dark:hover:bg-gray-700"
        >
          <.icon name="fa-xmark" />
          <span class="sr-only">{gettext("Close menu")}</span>
        </button>
      </div>

      <div class="mt-5 space-y-5">
        <.search_select
          id="filter_vehicle_id"
          name="vehicle_id"
          value={@filters["vehicle_id"]}
          label={gettext("Vehicle")}
          prompt={gettext("Any vehicle")}
          options={@vehicles}
        />

        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Fuel type")}</span>
          <div class="grid grid-cols-2 gap-2">
            <label
              :for={type <- FuelManagement.FuelType.values()}
              class="flex items-center gap-2 text-sm text-body"
            >
              <input
                type="checkbox"
                name="fuel_types[]"
                value={type}
                checked={to_string(type) in (@filters["fuel_types"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {humanize(type)}
            </label>
          </div>
        </div>

        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Payment method")}</span>
          <div class="grid grid-cols-2 gap-2">
            <label
              :for={method <- FuelManagement.PaymentMethod.values()}
              class="flex items-center gap-2 text-sm text-body"
            >
              <input
                type="checkbox"
                name="payment_methods[]"
                value={method}
                checked={to_string(method) in (@filters["payment_methods"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {humanize(method)}
            </label>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <.date_input
            id="filter_refueled_from"
            name="refueled_from"
            value={@filters["refueled_from"]}
            label={gettext("From")}
          />
          <.date_input
            id="filter_refueled_to"
            name="refueled_to"
            value={@filters["refueled_to"]}
            label={gettext("To")}
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
      "vehicle_id" => nilify(params["vehicle_id"]),
      "fuel_types" => params["fuel_types"] || [],
      "payment_methods" => params["payment_methods"] || [],
      "refueled_from" => nilify(params["refueled_from"]),
      "refueled_to" => nilify(params["refueled_to"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/o/#{org(socket)}/fuel?#{%{"q" => socket.assigns.query}}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, entry} <- FuelManagement.get_fuel_entry(id, scope: scope),
         :ok <- FuelManagement.delete_fuel_entry(entry, scope: scope) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext("Fuel entry archived. Restore it any time from Show archived.")
       )
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that fuel entry."))}
    end
  end

  # Archived entries are hidden from `get_fuel_entry`, so restore the record we already
  # loaded into the archived list rather than looking it up.
  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with entry when not is_nil(entry) <- Enum.find(socket.assigns.entries, &(&1.id == id)),
         {:ok, _} <- FuelManagement.restore_fuel_entry(entry, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Fuel entry restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that fuel entry."))}
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

    ~p"/o/#{org(socket)}/fuel?#{params}"
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/fuel"
    else
      ~p"/o/#{org(assigns)}/fuel?#{%{"archived" => "1"}}"
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
      "vehicle_id" => f["vehicle_id"],
      "fuel_types" => f["fuel_types"] || [],
      "payment_methods" => f["payment_methods"] || [],
      "refueled_from" => f["refueled_from"],
      "refueled_to" => f["refueled_to"]
    }
  end

  defp parse_filters(params) do
    fuel_types = to_string_list(params["fuel_types"], FuelManagement.FuelType)
    payment_methods = to_string_list(params["payment_methods"], FuelManagement.PaymentMethod)

    %{
      "vehicle_id" => nilify(params["vehicle_id"]),
      "fuel_types" => fuel_types,
      "payment_methods" => payment_methods,
      "refueled_from" => nilify(params["refueled_from"]),
      "refueled_to" => nilify(params["refueled_to"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  # Keep only values that are valid enum members (as strings).
  defp to_string_list(value, enum_module) do
    valid = MapSet.new(enum_module.values(), &to_string/1)
    value |> List.wrap() |> Enum.filter(&(&1 in valid))
  end

  @sortable ~w(refueled_at odometer quantity inserted_at)a
  defp sort_by(value), do: Enum.find(@sortable, :refueled_at, &(to_string(&1) == value))

  defp sort_order("asc"), do: :asc
  defp sort_order(_), do: :desc

  defp next_sort(%{sort_by: current, sort_order: order}, by) do
    by_atom = sort_by(by)

    cond do
      by_atom != current -> {to_string(by_atom), "desc"}
      order == :desc -> {to_string(by_atom), "asc"}
      true -> {to_string(by_atom), "desc"}
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
    case Fleetms.VehicleManagement.list_selectable_vehicles(scope: scope) do
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

  defp vehicle_name(%{vehicle: %{name: name}}), do: name
  defp vehicle_name(_), do: "—"

  defp humanize(nil), do: "—"

  defp humanize(value),
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp fmt_money(%Money{} = money), do: Money.to_string!(money)
  defp fmt_money(_), do: "—"

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(%{archived_view: true}, _entry), do: nil

  defp row_navigate(assigns, entry),
    do: JS.navigate(~p"/o/#{org(assigns)}/fuel/#{entry.id}/edit")
end
