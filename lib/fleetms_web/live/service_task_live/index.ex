defmodule FleetmsWeb.ServiceTaskLive.Index do
  @moduledoc """
  Lists an organization's service tasks (the maintenance-work catalogue) with
  search, sortable columns and pagination. All list state lives in the URL query
  string. Rows open the task for editing.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  @limit 20
  @sortable ~w(name inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Service Tasks"), active_link: :maintenance)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    sort_by = sort_by(params["sort"], @sortable, :name)
    sort_order = sort_order(params["dir"])
    page = page_number(params["page"])

    result =
      Maintenance.list_service_tasks(
        %{search_query: query, sort_by: sort_by, sort_order: sort_order},
        scope: scope,
        page: [limit: @limit, offset: (page - 1) * @limit, count: true]
      )

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            service_tasks: page_data.results,
            count: page_data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            can_create: Scope.has_permission?(scope, :create_service_task),
            can_update: Scope.has_permission?(scope, :update_service_task),
            can_delete: Scope.has_permission?(scope, :delete_service_task)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to service tasks here."))
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
        %{label: gettext("Service Tasks")}
      ]} />

      <.header>
        {gettext("Service Tasks")}
        <:subtitle>{gettext("%{count} in the catalogue.", count: @count)}</:subtitle>
        <:actions>
          <.button :if={@can_create} navigate={~p"/o/#{org(assigns)}/service-tasks/new"}>
            <.icon name="fa-plus" class="me-2" /> {gettext("New service task")}
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
                placeholder={gettext("Search service tasks…")}
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
                  label={gettext("Added")}
                  field="inserted_at"
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
                :for={task <- @service_tasks}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, task)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {task.name}
                </th>
                <td phx-click={row_navigate(assigns, task)} class="cursor-pointer px-4 py-3">
                  {task.description || "—"}
                </td>
                <td
                  phx-click={row_navigate(assigns, task)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3"
                >
                  {Fleetms.Format.date(task.inserted_at, org(assigns))}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/service-tasks/#{task.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={@can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={task.id}
                      data-confirm={gettext("Delete this service task?")}
                    >
                      {gettext("Delete")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@service_tasks == []}>
                <td colspan="4" class="px-4 py-6">
                  <.empty_state
                    icon="fa-list-check"
                    title={gettext("No service tasks found")}
                    message={gettext("Define the maintenance tasks your fleet uses.")}
                  >
                    <.button
                      :if={@can_create}
                      navigate={~p"/o/#{org(assigns)}/service-tasks/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Add service task")}
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

    with {:ok, task} <- Maintenance.get_service_task(id, scope: scope),
         :ok <- Maintenance.delete_service_task(task, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Service task deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that service task."))}
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

    ~p"/o/#{org(socket)}/service-tasks?#{params}"
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(assigns, task),
    do: JS.navigate(~p"/o/#{org(assigns)}/service-tasks/#{task.id}/edit")
end
