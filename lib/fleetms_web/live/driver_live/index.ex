defmodule FleetmsWeb.DriverLive.Index do
  @moduledoc """
  Lists the organization's drivers with search, a status filter, sortable columns
  and pagination. Highlights an expired or soon-to-expire driving licence. Rows open
  the driver for editing; entries can be archived and restored. All list state lives
  in the URL query string.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Drivers
  alias Fleetms.Format
  alias Fleetms.Scope

  @limit 20
  @soon_days 30
  @sortable ~w(last_name first_name license_expiry inserted_at)a
  @statuses ~w(active inactive)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Drivers"), active_link: :drivers)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    archived? = params["archived"] == "1"
    sort_by = sort_by(params["sort"], @sortable, :last_name)
    sort_order = sort_order(params["dir"] || "asc")
    filters = parse_filters(params)
    page = page_number(params["page"])

    opts = [scope: scope, page: [limit: @limit, offset: (page - 1) * @limit, count: true]]

    result =
      if archived? do
        Drivers.list_archived_drivers(
          %{search_query: query, sort_by: sort_by, sort_order: sort_order},
          opts
        )
      else
        Drivers.list_drivers(
          %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
          opts
        )
      end

    socket =
      case result do
        {:ok, data} ->
          assign(socket,
            drivers: data.results,
            count: data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            statuses: @statuses,
            can_create: Scope.has_permission?(scope, :create_driver),
            can_update: Scope.has_permission?(scope, :update_driver),
            can_delete: Scope.has_permission?(scope, :delete_driver)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to drivers here."))
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
        %{label: gettext("Drivers")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived drivers"), else: gettext("Drivers")}
        <:subtitle>
          {if @archived_view,
            do: gettext("%{count} archived", count: @count),
            else: gettext("%{count} on the roster", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/drivers/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New driver")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          :if={not @archived_view}
          query={@query}
          filter_count={map_size(@filters)}
          drawer_id="driver-filters"
          placeholder={gettext("Search name, licence or phone…")}
        />
        <div :if={@archived_view} class="border-b border-default p-4">
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
                placeholder={gettext("Search name, licence or phone…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <.sort_th
                  label={gettext("Name")}
                  field="last_name"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Contact")}</th>
                <.sort_th
                  label={gettext("Licence")}
                  field="license_expiry"
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
                :for={driver <- @drivers}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, driver)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {driver.first_name} {driver.last_name}
                </th>
                <td phx-click={row_navigate(assigns, driver)} class="cursor-pointer px-4 py-3">
                  <span class="block">{driver.phone}</span>
                  <span class="block text-xs text-body">{driver.email}</span>
                </td>
                <td phx-click={row_navigate(assigns, driver)} class="cursor-pointer px-4 py-3">
                  <span :if={driver.license_number}>
                    {driver.license_number}
                    <span :if={driver.license_class} class="text-xs text-body">
                      · {driver.license_class}
                    </span>
                  </span>
                  <.license_badge expiry={driver.license_expiry} org={org(assigns)} />
                </td>
                <td phx-click={row_navigate(assigns, driver)} class="cursor-pointer px-4 py-3">
                  <.badge color={if driver.status == :active, do: "success", else: "gray"}>
                    {humanize(driver.status)}
                  </.badge>
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={driver.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/drivers/#{driver.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={driver.id}
                      data-confirm={gettext("Archive this driver? You can restore them later.")}
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@drivers == []}>
                <td colspan="5" class="px-4 py-6">
                  <.empty_state
                    icon="fa-id-card"
                    title={
                      if @archived_view,
                        do: gettext("No archived drivers"),
                        else: gettext("No drivers found")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Add the people who drive your vehicles, licence and all.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/drivers/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New driver")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer :if={not @archived_view} id="driver-filters">
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
              {String.capitalize(st)}
            </label>
          </div>
        </div>
      </.filter_drawer>
    </Layouts.app>
    """
  end

  attr :expiry, :any, required: true
  attr :org, :any, required: true

  defp license_badge(%{expiry: nil} = assigns), do: ~H""

  defp license_badge(assigns) do
    days = Date.diff(assigns.expiry, Date.utc_today())
    assigns = assign(assigns, expired: days < 0, soon: days >= 0 and days <= @soon_days)

    ~H"""
    <span
      :if={@expired}
      class="ms-1 rounded bg-red-100 px-1.5 py-0.5 text-xs font-medium text-red-800 dark:bg-red-900 dark:text-red-200"
    >
      {gettext("Expired")}
    </span>
    <span
      :if={@soon}
      class="ms-1 rounded bg-amber-100 px-1.5 py-0.5 text-xs font-medium text-amber-800 dark:bg-amber-900 dark:text-amber-200"
    >
      {gettext("Expires %{date}", date: Format.date(@expiry, @org))}
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
        sort_by(by, @sortable, :last_name)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    overrides = %{"status" => params["status"] || [], "page" => nil}
    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/o/#{org(socket)}/drivers?#{prune(%{"q" => socket.assigns.query})}"
     )}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, driver} <- Drivers.get_driver(id, scope: scope),
         :ok <- Drivers.delete_driver(driver, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Driver archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that driver."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with driver when not is_nil(driver) <- Enum.find(socket.assigns.drivers, &(&1.id == id)),
         {:ok, _} <- Drivers.restore_driver(driver, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Driver restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that driver."))}
    end
  end

  # --- URL <-> state ---

  defp index_path(socket, overrides) do
    f = socket.assigns.filters

    params =
      %{
        "q" => socket.assigns.query,
        "archived" => if(socket.assigns.archived_view, do: "1"),
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "status" => f["statuses"] || []
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/drivers?#{params}"
  end

  defp parse_filters(params) do
    %{"statuses" => Enum.filter(List.wrap(params["status"]), &(&1 in @statuses))}
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/drivers"
    else
      ~p"/o/#{org(assigns)}/drivers?#{%{"archived" => "1"}}"
    end
  end

  defp row_navigate(%{archived_view: true}, _driver), do: nil

  defp row_navigate(assigns, driver),
    do: JS.navigate(~p"/o/#{org(assigns)}/drivers/#{driver.id}/edit")

  defp humanize(value), do: value |> to_string() |> String.capitalize()

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
