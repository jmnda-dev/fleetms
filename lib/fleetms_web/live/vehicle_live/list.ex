defmodule FleetmsWeb.VehicleLive.List do
  alias Fleetms.VehicleManagement.VehicleListFilter
  use FleetmsWeb, :live_view
  import Fleetms.Utils, only: [calc_total_pages: 2, atom_list_to_options_for_select: 1]
  alias Fleetms.Common.PaginationSortParam
  alias Fleetms.VehicleManagement

  # alias FleetmsWeb.LiveUserAuth
  #
  # on_mount {LiveUserAuth, :vehicles_module}

  @per_page_opts [10, 20, 30, 50, 100, 250, 500]
  @sort_by_opts [
    :name,
    :vehicle_make,
    :model,
    :type,
    :created_at,
    :updated_at,
    :year,
    :mileage
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
      |> assign(:active_link, :vehicles)
      |> stream(:vehicles, [])
      |> assign(:total, 0)
      |> assign(:total_pages, 0)
      |> assign(:search_params, %{search_query: ""})
      |> assign(:has_more?, false)
      |> assign(:applied_filters, %{})

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    paginate_sort_opts = validate_paginate_sort_params(params)
    search_query = Map.get(params, "search_query", "")

    {socket, filters} =
      with query_params <- get_applied_filters(params),
           {:ok, %VehicleListFilter{} = filters_struct} <-
             VehicleManagement.VehicleListFilter.validate(query_params) do
        {socket, VehicleListFilter.to_params!(filters_struct)}
      else
        {:error, _changeset} ->
          {put_toast(socket, :error, "URL contains invalid filters, no filters applied!"), %{}}
      end

    %{page: page, per_page: per_page} = paginate_sort_opts

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:applied_filters, filters)
      |> start_async(:get_vehicles, fn ->
        VehicleManagement.list_vehicles!(paginate_sort_opts, search_query, filters,
          tenant: tenant,
          actor: actor,
          page: [limit: per_page, offset: (page - 1) * per_page, count: true]
        )
      end)

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_async(:get_vehicles, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:vehicles, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_vehicles, {:exit, _reason}, socket) do
    {:noreply, assign(socket, :loading, :error)}
  end

  @impl true
  def handle_event(
        "selected_vehicle_make",
        %{"vehicle_make" => vehicle_make},
        socket
      ) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicle_models =
      Fleetms.VehicleManagement.VehicleModel.list_by_vehicle_make!(vehicle_make,
        tenant: tenant,
        actor: actor
      )

    send_update(FleetmsWeb.VehicleLive.FormComponent,
      id: "vehicle-form-component",
      vehicle_models: vehicle_models
    )

    {:noreply, socket}
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
      |> Map.merge(socket.assigns.applied_filters)

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}
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
      |> Map.merge(socket.assigns.applied_filters)

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.applied_filters)

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"vehicle_search" => vehicle_search}, socket) do
    search_params = %{search_query: vehicle_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.paginate_sort_opts)
      |> Map.merge(socket.assigns.applied_filters)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.VehicleManagement.Vehicle, :destroy}, actor)

    if can_perform_action? do
      vehicle = Fleetms.VehicleManagement.Vehicle.get_by_id!(id, tenant: tenant, actor: actor)

      Ash.destroy!(vehicle, tenant: tenant, actor: actor)

      socket =
        socket
        |> stream_delete(:vehicles, vehicle)
        |> put_toast(:info, "Vehicle was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp apply_action(socket, :edit, %{"id" => id} = _params) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.VehicleManagement.Vehicle, :update}, actor)

    if can_perform_action? do
      vehicle = Fleetms.VehicleManagement.Vehicle.get_by_id!(id, tenant: tenant, actor: actor)

      socket
      |> assign(:page_title, "Edit Vehicle Details")
      |> assign(:vehicle, vehicle)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :add, _params) do
    actor = socket.assigns.current_user

    can_perform_action? =
      Ash.can?({Fleetms.VehicleManagement.Vehicle, :create}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Add Vehicle")
      |> assign(:vehicle, nil)
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Advanced Vehicle Filter Form")
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Vehicle Listing")
    |> assign(:form, nil)
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

  defp get_applied_filters(params) do
    applied_filters =
      Map.take(params, [
        "mileage_min",
        "mileage_max",
        "year_min",
        "year_max",
        "types",
        "statuses",
        "categories",
        "make",
        "model"
      ])

    applied_filters
  end

  defp get_items_per_page_opts, do: @per_page_opts
  defp get_sort_by_opts, do: atom_list_to_options_for_select(@sort_by_opts)
  defp get_sort_order_opts, do: atom_list_to_options_for_select(@sort_order)
end
