defmodule FleetmsWeb.InventoryLocationLive.Index do
  use FleetmsWeb, :live_view

  import Fleetms.Utils, only: [calc_total_pages: 2, atom_list_to_options_for_select: 1]
  alias Fleetms.Common.PaginationSortParam
  alias Fleetms.Inventory

  @per_page_opts [10, 20, 30, 50, 100, 250, 500]
  @sort_by_opts [
    :created_at,
    :updated_at,
    :name
  ]
  @default_listing_limit 20
  @sort_order [:asc, :desc]
  @default_paginate_sort_params %{
    page: 1,
    per_page: @default_listing_limit,
    sort_by: :updated_at,
    sort_order: :desc
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_link, :inventory_locations)
      |> stream(:inventory_locations, [])
      |> assign(:total, 0)
      |> assign(:total_pages, 0)
      |> assign(:search_params, %{search_query: ""})
      |> assign(:has_more?, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    paginate_sort_opts = validate_paginate_sort_params(params)

    search_query = Map.get(params, "search_query", "")

    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> start_async(:get_inventory_locations, fn ->
        list_inventory_locations(
          paginate_sort_opts,
          search_query,
          tenant: tenant,
          actor: actor
        )
      end)

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_async(:get_inventory_locations, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:inventory_locations, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))


    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_inventory_locations, {:error, _reason}, socket) do
    {:noreply, assign(socket, :loading, :error)}
  end

  @impl true
  def handle_event(
        "items_per_page_changed",
        %{"paginate_sort_opts" => %{"per_page" => per_page}},
        socket
      ) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:per_page, per_page)
      |> Map.merge(socket.assigns.search_params)

    {:noreply, push_patch(socket, to: ~p"/inventory_locations?#{new_url_params}")}
  end

  @impl true
  def handle_event(
        "sort_order_changed",
        %{"paginate_sort_opts" => %{"sort_order" => sort_order}},
        socket
      ) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_order, sort_order)
      |> Map.merge(socket.assigns.search_params)

    {:noreply, push_patch(socket, to: ~p"/inventory_locations?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)

    {:noreply, push_patch(socket, to: ~p"/inventory_locations?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"inventory_location_search" => inventory_location_search}, socket) do
    search_params = %{search_query: inventory_location_search["search_query"]}

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/inventory_locations?#{search_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    inventory_location =
      Fleetms.Inventory.InventoryLocation.get_by_id!(id, tenant: tenant, actor: actor)

    Ash.destroy!(inventory_location, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream_delete(:inventory_locations, inventory_location)
      |> put_flash(:info, "#{inventory_location.name} was deleted successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {FleetmsWeb.InventoryLocationLive.FormComponent, {:saved, inventory_location}},
        socket
      ) do
    {:noreply, stream_insert(socket, :inventory_locations, inventory_location)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?(
        {Fleetms.Inventory.InventoryLocation, :update},
        actor
      )

    if can_perform_action? do
      inventory_location =
        Fleetms.Inventory.InventoryLocation.get_by_id!(id, tenant: tenant, actor: actor)

      socket
      |> assign(:page_title, "Edit Inventory Location ")
      |> assign(:inventory_location, inventory_location)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Listing Part Locations")
  end

  defp apply_action(socket, :new, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Inventory.InventoryLocation, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      socket
      |> assign(:page_title, "New Inventory Location ")
      |> assign(:inventory_location, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Inventory Locations")
    |> assign(:inventory_location, nil)
  end

  defp list_inventory_locations(paginate_sort_opts, search_query, opts) do
    %{page: page, per_page: per_page} = paginate_sort_opts

    Inventory.list_inventory_locations!(paginate_sort_opts, search_query,
      tenant: opts[:tenant],
      actor: opts[:actor],
      page: [limit: per_page, offset: (page - 1) * per_page, count: true]
    )
  end

  defp validate_paginate_sort_params(params) do
    paginate_sort_params = Map.take(params, ["page", "per_page", "sort_by", "sort_order"])

    case PaginationSortParam.validate(@per_page_opts, @sort_by_opts, paginate_sort_params) do
      {:ok, validated_params} ->
        Map.take(validated_params, [:page, :per_page, :sort_by, :sort_order])

      {:error, _error} ->
        @default_paginate_sort_params
    end
  end

  defp get_items_per_page_opts, do: @per_page_opts
  defp get_sort_by_opts, do: atom_list_to_options_for_select(@sort_by_opts)
  defp get_sort_order_opts, do: atom_list_to_options_for_select(@sort_order)
end
