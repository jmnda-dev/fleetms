defmodule FleetmsWeb.InventoryLocationLive.InventoryLocationPartTableComponent do
  use FleetmsWeb, :live_component

  require Ash.Query
  import Fleetms.Utils, only: [calc_total_pages: 2]

  @per_page_opts ["10", "15", "20", "30", "50", "75", "100", "150"]

  @impl true
  def mount(socket) do
    default_pagination_params =
      Fleetms.Inventory.Part.validate_pagination_params!(%{})

    default_sort_params =
      Fleetms.Inventory.Part.validate_sorting_params!(%{})

    paginate_sort_opts = Map.merge(default_pagination_params, default_sort_params)

    socket =
      socket
      |> stream(:parts, [])
      |> assign(:total, 0)
      |> assign(:total_pages, 0)
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: ""})
      |> assign(:has_more?, false)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    %{
      paginate_sort_opts: paginate_sort_opts,
      search_params: search_params,
      inventory_location: inventory_location,
      tenant: tenant,
      current_user: actor
    } = socket.assigns

    inventory_location_id = inventory_location.id

    socket =
      socket
      |> start_async(:get_parts, fn ->
        list_parts(
          tenant: tenant,
          actor: actor,
          paginate_sort_opts: paginate_sort_opts,
          search_query: search_params.search_query,
          inventory_location_id: inventory_location_id
        )
      end)

    {:ok, socket}
  end

  @impl true
  def handle_async(:get_parts, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:parts, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))

    # TODO: Initialize flowbite on client
    {:noreply, push_event(socket, "initFlowbiteJS", %{})}
  end

  @impl true
  def handle_async(:get_parts, {:error, _reason}, socket) do
    {:noreply, assign(socket, :loading, :error)}
  end

  @impl true
  def handle_event(
        "items_per_page_changed",
        %{"paginate_sort_opts" => %{"per_page" => per_page}},
        socket
      ) do
    # use page 1 instead of current page to reset the pagination, since its not necessary to maintain the current page if items per page is changed
    new_paginate_opts =
      Fleetms.Inventory.Part.validate_pagination_params!(%{"page" => 1, "per_page" => per_page})

    socket =
      update(socket, :paginate_sort_opts, fn paginate_sort_opts ->
        Map.merge(paginate_sort_opts, new_paginate_opts)
      end)

    send_update(__MODULE__,
      id: "inventory_location_parts-table",
      loading: true,
      tenant: socket.assigns.tenant
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "page_changed",
        %{"page" => page},
        socket
      ) do
    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    new_paginate_opts =
      Fleetms.Inventory.Part.validate_pagination_params!(%{"page" => page, "per_page" => per_page})

    socket =
      update(socket, :paginate_sort_opts, fn paginate_sort_opts ->
        Map.merge(paginate_sort_opts, new_paginate_opts)
      end)

    send_update(__MODULE__,
      id: "inventory_location_parts-table",
      loading: true,
      tenant: socket.assigns.tenant
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"part_search" => part_search}, socket) do
    search_params = %{search_query: part_search["search_query"]}

    socket = assign(socket, :search_params, search_params)

    send_update(__MODULE__,
      id: "inventory_location_parts-table",
      loading: true,
      tenant: socket.assigns.tenant
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    part = Fleetms.Inventory.Part.get_by_id!(id, tenant: tenant, actor: actor)

    Ash.destroy!(part, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream_delete(:parts, part)
      |> put_flash(:info, "#{part.name} was deleted successfully")

    {:noreply, socket}
  end

  defp list_parts(opts) do
    %{page: page, per_page: per_page} = opts[:paginate_sort_opts]

    Fleetms.Inventory.PartInventoryLocation
    |> Ash.Query.for_read(:list, %{
      paginate_sort_opts: opts[:paginate_sort_opts],
      search_query: opts[:search_query],
      inventory_location_id: opts[:inventory_location_id]
    })
    |> Ash.read!(
      tenant: opts[:tenant],
      actor: opts[:tenant],
      page: [limit: per_page, offset: (page - 1) * per_page, count: true]
    )
  end

  defp get_items_per_page_opts, do: @per_page_opts
end
