defmodule FleetmsWeb.ServiceGroupLive.Index do
  @moduledoc """
  Lists an organization's service groups (shared maintenance programmes) with
  search, sortable columns and pagination, showing how many vehicles and schedule
  lines each has. All list state lives in the URL query string. Rows open a group
  for editing.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  @limit 20
  @sortable ~w(name vehicle_count schedule_count inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Service Groups"), active_link: :maintenance)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    sort_by = sort_by(params["sort"], @sortable, :name)
    sort_order = sort_order(params["dir"])
    page = page_number(params["page"])

    result =
      Maintenance.list_service_groups(
        %{search_query: query, sort_by: sort_by, sort_order: sort_order},
        scope: scope,
        page: [limit: @limit, offset: (page - 1) * @limit, count: true]
      )

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            groups: page_data.results,
            count: page_data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            can_create: Scope.has_permission?(scope, :create_service_group),
            can_update: Scope.has_permission?(scope, :update_service_group),
            can_delete: Scope.has_permission?(scope, :delete_service_group)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to service groups here."))
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
        %{label: gettext("Service Groups")}
      ]} />

      <.header>
        {gettext("Service Groups")}
        <:subtitle>{gettext("%{count} shared maintenance programmes.", count: @count)}</:subtitle>
        <:actions>
          <.button :if={@can_create} navigate={~p"/o/#{org(assigns)}/service-groups/new"}>
            <.icon name="fa-plus" class="me-2" /> {gettext("New group")}
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
                placeholder={gettext("Search groups…")}
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
                <.sort_th
                  label={gettext("Vehicles")}
                  field="vehicle_count"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Schedule lines")}
                  field="schedule_count"
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
                :for={group <- @groups}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, group)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {group.name}
                </th>
                <td phx-click={row_navigate(assigns, group)} class="cursor-pointer px-4 py-3">
                  {group.vehicle_count}
                </td>
                <td phx-click={row_navigate(assigns, group)} class="cursor-pointer px-4 py-3">
                  {group.schedule_count}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/service-groups/#{group.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={@can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={group.id}
                      data-confirm={gettext("Delete this group? Its generated reminders go with it.")}
                    >
                      {gettext("Delete")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@groups == []}>
                <td colspan="4" class="px-4 py-6">
                  <.empty_state
                    icon="fa-layer-group"
                    title={gettext("No service groups found")}
                    message={
                      gettext("Group service tasks into a schedule you can apply to vehicles.")
                    }
                  >
                    <.button
                      :if={@can_create}
                      navigate={~p"/o/#{org(assigns)}/service-groups/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Add service group")}
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

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, group} <- Maintenance.get_service_group(id, scope: scope),
         :ok <- Maintenance.delete_service_group(group, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Service group deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that group."))}
    end
  end

  defp index_path(socket, overrides) do
    params =
      %{
        "q" => socket.assigns.query,
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page)
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/service-groups?#{params}"
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(assigns, group),
    do: JS.navigate(~p"/o/#{org(assigns)}/service-groups/#{group.id}/edit")
end
