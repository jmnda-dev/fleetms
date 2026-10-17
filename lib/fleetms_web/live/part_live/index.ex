defmodule FleetmsWeb.PartLive.Index do
  @moduledoc """
  Lists an organization's parts with search, a faceted filter drawer (category,
  stock status), sortable columns and pagination. All list state lives in the URL.
  Rows open the part for editing; total on-hand and its status are shown per row.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Inventory
  alias Fleetms.Scope

  @limit 20
  @statuses ["In stock", "Low", "Out of stock", "Not tracked"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Parts"), active_link: :inventory)}
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
        Inventory.list_archived_parts(%{search_query: query},
          scope: scope,
          load: [:tags],
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      else
        Inventory.list_parts(
          %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
          scope: scope,
          load: [:tags],
          page: [limit: @limit, offset: (page - 1) * @limit, count: true]
        )
      end

    socket =
      case result do
        {:ok, page_data} ->
          assign(socket,
            parts: page_data.results,
            count: page_data.count || 0,
            page: page,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            categories: category_options(scope),
            can_create: Scope.has_permission?(scope, :create_part),
            can_update: Scope.has_permission?(scope, :update_part),
            can_delete: Scope.has_permission?(scope, :delete_part)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to parts here."))
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
        %{label: gettext("Parts")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived parts"), else: gettext("Parts")}
        <:subtitle>
          {if @archived_view,
            do: gettext("%{count} archived", count: @count),
            else: gettext("%{count} in the catalogue", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/parts/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New part")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
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
                placeholder={gettext("Search part number, name, manufacturer…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>

          <div :if={not @archived_view} class="flex items-center gap-2">
            <.saved_views view_key="parts" />
            <button
              type="button"
              phx-hook="FilterDrawer"
              id="part-filters-trigger"
              aria-controls="part-filters"
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

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <.sort_th
                  label={gettext("Part #")}
                  field="part_number"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Name")}
                  field="name"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Category")}</th>
                <.sort_th
                  label={gettext("Stock")}
                  field="total_stock"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 text-right font-semibold">{gettext("Unit cost")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={part <- @parts}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, part)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {part.part_number}
                </th>
                <td phx-click={row_navigate(assigns, part)} class="cursor-pointer px-4 py-3">
                  {part.name || "—"}
                  <.tag_list :if={part.tags != []} tags={part.tags} class="mt-1" />
                </td>
                <td phx-click={row_navigate(assigns, part)} class="cursor-pointer px-4 py-3">
                  {category_name(part)}
                </td>
                <td phx-click={row_navigate(assigns, part)} class="cursor-pointer px-4 py-3">
                  <div class="flex items-center gap-2">
                    <span class="text-heading">{fmt_num(part.total_stock)}</span>
                    <.badge color={status_color(part.stock_status)}>{part.stock_status}</.badge>
                  </div>
                </td>
                <td
                  phx-click={row_navigate(assigns, part)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 text-right"
                >
                  {fmt_money(part.unit_cost)}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={part.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/parts/#{part.id}/stock"}
                    >
                      {gettext("Stock")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/parts/#{part.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={part.id}
                      data-confirm={
                        gettext("Archive this part? You can restore it later from Show archived.")
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@parts == []}>
                <td colspan="6" class="px-4 py-6">
                  <.empty_state
                    icon="fa-box"
                    title={
                      if @archived_view,
                        do: gettext("No archived parts"),
                        else: gettext("No parts yet")
                    }
                    message={
                      unless @archived_view, do: gettext("Add a part to start tracking inventory.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/parts/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Add part")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

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

      <.part_filter_drawer categories={@categories} filters={@filters} statuses={statuses()} />
    </Layouts.app>
    """
  end

  attr :categories, :list, required: true
  attr :filters, :map, required: true
  attr :statuses, :list, required: true

  defp part_filter_drawer(assigns) do
    ~H"""
    <form
      id="part-filters"
      phx-submit="apply-filters"
      tabindex="-1"
      aria-labelledby="part-filters-label"
      class="fixed left-0 top-0 z-40 h-screen w-full max-w-sm -translate-x-full overflow-y-auto bg-white p-4 transition-transform dark:bg-gray-800"
    >
      <div class="flex items-center justify-between">
        <h5
          id="part-filters-label"
          class="inline-flex items-center text-base font-semibold uppercase text-heading"
        >
          <.icon name="fa-filter" class="me-2" /> {gettext("Filters")}
        </h5>
        <button
          type="button"
          data-drawer-close
          aria-controls="part-filters"
          class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-body hover:bg-gray-100 hover:text-heading dark:hover:bg-gray-700"
        >
          <.icon name="fa-xmark" />
          <span class="sr-only">{gettext("Close menu")}</span>
        </button>
      </div>

      <div class="mt-5 space-y-5">
        <.search_select
          id="filter_category_id"
          name="category_id"
          value={@filters["category_id"]}
          label={gettext("Category")}
          prompt={gettext("Any category")}
          options={@categories}
        />

        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Stock status")}</span>
          <div class="space-y-2">
            <label :for={status <- @statuses} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="statuses[]"
                value={status}
                checked={status in (@filters["statuses"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {status}
            </label>
          </div>
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
      "category_id" => nilify(params["category_id"]),
      "statuses" => params["statuses"] || [],
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/o/#{org(socket)}/parts?#{%{"q" => socket.assigns.query}}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, part} <- Inventory.get_part(id, scope: scope),
         :ok <- Inventory.delete_part(part, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Part archived. Restore it any time from Show archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that part."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, part} <- Inventory.get_part(id, scope: scope),
         {:ok, _} <- Inventory.restore_part(part, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Part restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      {:error, %Ash.Error.Invalid{}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Can't restore: a live part already uses that part number.")
         )}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Could not restore that part."))}
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

    ~p"/o/#{org(socket)}/parts?#{params}"
  end

  # Switch between the active and archived views, resetting page/filters.
  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/parts"
    else
      ~p"/o/#{org(assigns)}/parts?#{%{"archived" => "1"}}"
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
      "category_id" => f["category_id"],
      "statuses" => f["statuses"] || []
    }
  end

  defp parse_filters(params) do
    statuses = params["statuses"] |> List.wrap() |> Enum.filter(&(&1 in @statuses))

    %{
      "category_id" => nilify(params["category_id"]),
      "statuses" => statuses
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  @sortable ~w(part_number name total_stock inserted_at)a
  defp sort_by(value), do: Enum.find(@sortable, :part_number, &(to_string(&1) == value))

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

  defp category_options(scope) do
    Inventory.list_part_categories!(scope: scope, query: [sort: [name: :asc]])
    |> Enum.map(&{&1.name, &1.id})
  end

  defp total_pages(count), do: max(1, ceil(count / @limit))

  defp range_label(0, _page), do: "0"

  defp range_label(count, page) do
    from = (page - 1) * @limit + 1
    to = min(page * @limit, count)
    "#{from}–#{to}"
  end

  defp statuses, do: @statuses

  defp status_color("In stock"), do: "success"
  defp status_color("Low"), do: "warning"
  defp status_color("Out of stock"), do: "danger"
  defp status_color(_), do: "gray"

  defp category_name(%{category: %{name: name}}), do: name
  defp category_name(_), do: "—"

  defp fmt_num(nil), do: "—"
  # `:normal` avoids scientific notation (normalize turns 50 into 5E+1 otherwise).
  defp fmt_num(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp fmt_money(%Money{} = money), do: Money.to_string!(money)
  defp fmt_money(_), do: "—"

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(%{archived_view: true}, _part), do: nil
  defp row_navigate(assigns, part), do: JS.navigate(~p"/o/#{org(assigns)}/parts/#{part.id}/edit")
end
