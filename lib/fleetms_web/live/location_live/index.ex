defmodule FleetmsWeb.LocationLive.Index do
  @moduledoc """
  Lists an organization's inventory locations (where parts are stored) with search,
  sortable columns and pagination, plus an archived view. Each row shows how many
  parts are stocked there. All list state lives in the URL query string.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Inventory
  alias Fleetms.Scope

  @limit 20
  @sortable ~w(name part_count inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Inventory Locations"), active_link: :inventory)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    archived? = params["archived"] == "1"
    sort_by = sort_by(params["sort"], @sortable, :name)
    sort_order = sort_order(params["dir"] || "asc")
    page = page_number(params["page"])

    args = %{search_query: query, sort_by: sort_by, sort_order: sort_order}
    opts = [scope: scope, page: [limit: @limit, offset: (page - 1) * @limit, count: true]]

    result =
      if archived? do
        Inventory.list_archived_inventory_locations(args, opts)
      else
        Inventory.list_inventory_locations(args, opts)
      end

    socket =
      case result do
        {:ok, data} ->
          assign(socket,
            locations: data.results,
            count: data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            archived_view: archived?,
            can_create: Scope.has_permission?(scope, :create_inventory_location),
            can_update: Scope.has_permission?(scope, :update_inventory_location),
            can_delete: Scope.has_permission?(scope, :delete_inventory_location)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to inventory locations here."))
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
        %{label: gettext("Inventory Locations")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived locations"), else: gettext("Inventory Locations")}
        <:subtitle>
          {if @archived_view,
            do: gettext("Archived locations can be restored."),
            else: gettext("%{count} places parts are stored.", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/inventory-locations/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New location")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div class="border-b border-default p-4">
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
                placeholder={gettext("Search locations…")}
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
                  field="name"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Description")}</th>
                <.sort_th
                  label={gettext("Parts")}
                  field="part_count"
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
                :for={location <- @locations}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, location)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {location.name}
                </th>
                <td phx-click={row_navigate(assigns, location)} class="cursor-pointer px-4 py-3">
                  {location.description || "—"}
                </td>
                <td phx-click={row_navigate(assigns, location)} class="cursor-pointer px-4 py-3">
                  {location.part_count}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={location.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/inventory-locations/#{location.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={location.id}
                      data-confirm={
                        gettext("Archive this location? You can restore it later from Show archived.")
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@locations == []}>
                <td colspan="4" class="px-4 py-6">
                  <.empty_state
                    icon="fa-location-dot"
                    title={
                      if @archived_view,
                        do: gettext("No archived locations"),
                        else: gettext("No locations found")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Add storerooms or sites where you keep parts.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/inventory-locations/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Add location")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"q" => nilify(q), "page" => nil}))}
  end

  def handle_event("sort", %{"by" => by}, socket) do
    {sort, dir} =
      next_sort(socket.assigns.sort_by, socket.assigns.sort_order, sort_by(by, @sortable, :name))

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, location} <- Inventory.get_inventory_location(id, scope: scope),
         :ok <- Inventory.delete_inventory_location(location, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Location archived. Restore it any time from Show archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that location."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, location} <- Inventory.get_inventory_location(id, scope: scope),
         {:ok, _} <- Inventory.restore_inventory_location(location, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Location restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      {:error, %Ash.Error.Invalid{}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Can't restore: a live location already uses that name.")
         )}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not restore that location."))}
    end
  end

  # Preserve the active/archived view, search, sort and page across a patch.
  defp index_path(socket, overrides) do
    params =
      %{
        "q" => socket.assigns.query,
        "archived" => if(socket.assigns.archived_view, do: "1"),
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page)
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/inventory-locations?#{params}"
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/inventory-locations"
    else
      ~p"/o/#{org(assigns)}/inventory-locations?#{%{"archived" => "1"}}"
    end
  end

  defp row_navigate(%{archived_view: true}, _location), do: nil

  defp row_navigate(assigns, location),
    do: JS.navigate(~p"/o/#{org(assigns)}/inventory-locations/#{location.id}/edit")

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
