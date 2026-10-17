defmodule FleetmsWeb.VendorLive.Index do
  @moduledoc """
  Lists an organization's vendors (outside suppliers / repair shops) with search,
  sortable columns and pagination, plus an archived view. All list state lives in
  the URL query string. Rows open the vendor for editing.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Maintenance
  alias Fleetms.Scope

  @limit 20
  @sortable ~w(name contact_name inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Vendors"), active_link: :maintenance)}
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
        Maintenance.list_archived_vendors(args, opts)
      else
        Maintenance.list_vendors(args, opts)
      end

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            vendors: page_data.results,
            count: page_data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            archived_view: archived?,
            can_create: Scope.has_permission?(scope, :create_vendor),
            can_update: Scope.has_permission?(scope, :update_vendor),
            can_delete: Scope.has_permission?(scope, :delete_vendor)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to vendors here."))
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
        %{label: gettext("Vendors")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived vendors"), else: gettext("Vendors")}
        <:subtitle>
          {if @archived_view,
            do: gettext("Archived vendors can be restored."),
            else: gettext("%{count} suppliers and repair shops.", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/vendors/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New vendor")}
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
                placeholder={gettext("Search vendors…")}
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
                  label={gettext("Contact")}
                  field="contact_name"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Phone")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={vendor <- @vendors}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, vendor)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {vendor.name}
                </th>
                <td phx-click={row_navigate(assigns, vendor)} class="cursor-pointer px-4 py-3">
                  {vendor.contact_name || "—"}
                </td>
                <td phx-click={row_navigate(assigns, vendor)} class="cursor-pointer px-4 py-3">
                  {vendor.phone || "—"}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={vendor.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/vendors/#{vendor.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={vendor.id}
                      data-confirm={
                        gettext("Archive this vendor? You can restore it later from Show archived.")
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@vendors == []}>
                <td colspan="4" class="px-4 py-6">
                  <.empty_state
                    icon="fa-store"
                    title={
                      if @archived_view,
                        do: gettext("No archived vendors"),
                        else: gettext("No vendors found")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Add the suppliers and garages you work with.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/vendors/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Add vendor")}
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

    with {:ok, vendor} <- Maintenance.get_vendor(id, scope: scope),
         :ok <- Maintenance.delete_vendor(vendor, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Vendor archived. Restore it any time from Show archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that vendor."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, vendor} <- Maintenance.get_vendor(id, scope: scope),
         {:ok, _} <- Maintenance.restore_vendor(vendor, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Vendor restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      {:error, %Ash.Error.Invalid{}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Can't restore: a live vendor already uses that name.")
         )}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not restore that vendor."))}
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

    ~p"/o/#{org(socket)}/vendors?#{params}"
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/vendors"
    else
      ~p"/o/#{org(assigns)}/vendors?#{%{"archived" => "1"}}"
    end
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(%{archived_view: true}, _vendor), do: nil

  defp row_navigate(assigns, vendor),
    do: JS.navigate(~p"/o/#{org(assigns)}/vendors/#{vendor.id}/edit")
end
