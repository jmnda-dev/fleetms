defmodule FleetmsWeb.FuelHistoryLive.Index do
  use FleetmsWeb, :live_view

  import Fleetms.Utils,
    only: [calc_total_pages: 2, dates_in_map_to_string: 2, atom_list_to_options_for_select: 1]

  alias Fleetms.Common.PaginationSortParam
  alias Fleetms.FuelTracking

  @per_page_opts [10, 20, 30, 50, 100, 250, 500]
  @sort_by_opts [
    :refuel_datetime,
    :odometer_reading,
    :refuel_quantity,
    :refuel_cost,
    :fuel_type,
    :payment_method,
    :created_at,
    :updated_at
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
      |> assign(:active_link, :fuel_histories)
      |> stream(:fuel_histories, [])
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

    filter_form_data = filter_form_data_from_url_params(params)

    filter_form_data_with_string_dates =
      filter_form_data
      |> dates_in_map_to_string([
        :refuel_date_from,
        :refuel_date_to
      ])

    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:filter_form_data, filter_form_data_with_string_dates)
      |> start_async(:get_fuel_histories, fn ->
        list_fuel_histories(
          paginate_sort_opts,
          search_query,
          filter_form_data,
          tenant: tenant,
          actor: actor
        )
      end)

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_async(:get_fuel_histories, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:fuel_histories, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))


    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_fuel_histories, {:exit, _reason}, socket) do
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
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/fuel_histories?#{new_url_params}")}
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
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/fuel_histories?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/fuel_histories?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"fuel_history_search" => fuel_history_search}, socket) do
    search_params = %{search_query: fuel_history_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.paginate_sort_opts)
      |> Map.merge(socket.assigns.filter_form_data)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/fuel_histories?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    socket.assigns(
      fuel_history =
        Fleetms.FuelTracking.FuelHistory.get_by_id!(id, tenant: tenant, actor: actor)
    )

    Ash.destroy!(fuel_history, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream_delete(:fuel_histories, fuel_history)
      |> put_flash(:info, "Fuel History was deleted successfully")

    {:noreply, socket}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?(
        {Fleetms.FuelTracking.FuelHistory, :update},
        actor
      )

    if can_perform_action? do
      socket
      |> assign(:page_title, "Edit Fuel History")
      |> assign(
        :fuel_history,
        Fleetms.FuelTracking.FuelHistory.get_by_id!(id, tenant: tenant, actor: actor)
      )
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Advanced Fuel History Filter Form")
  end

  defp apply_action(socket, :new, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.FuelTracking.FuelHistory, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      socket
      |> assign(:page_title, "New Fuel History")
      |> assign(:fuel_history, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Fuel Histories")
    |> assign(:fuel_history, nil)
  end

  @impl true
  def handle_info({FleetmsWeb.FuelHistoryLive.FormComponent, {:saved, fuel_history}}, socket) do
    {:noreply, stream_insert(socket, :fuel_histories, fuel_history)}
  end

  defp list_fuel_histories(paginate_sort_opts, search_query, filter_form_data, opts) do
    %{page: page, per_page: per_page} = paginate_sort_opts

    FuelTracking.list_fuel_histories!(paginate_sort_opts, search_query, filter_form_data,
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

  defp filter_form_data_from_url_params(url_params) do
    default_params = %{
      odometer_reading_min: 0,
      odometer_reading_max: 999_999_999,
      refuel_date_from: ~D[1970-01-01],
      refuel_date_to: Date.utc_today()
    }

    params =
      Map.take(url_params, [
        "odometer_reading_min",
        "odometer_reading_max",
        "refuel_date_from",
        "refuel_date_to",
        "refuel_quantity_min",
        "refuel_quantity_max",
        "refuel_cost_min",
        "refuel_cost_max",
        "vehicles",
        "refueled_by",
        "fuel_types",
        "payment_methods"
      ])

    FleetmsWeb.FuelHistoryLive.FilterFormComponent.build_filter_changeset(%{}, params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, validated_filter_params} ->
        validated_filter_params

      {:error, _changeset} ->
        default_params
    end
  end

  defp get_items_per_page_opts, do: @per_page_opts
  defp get_sort_by_opts, do: atom_list_to_options_for_select(@sort_by_opts)
  defp get_sort_order_opts, do: atom_list_to_options_for_select(@sort_order)
end
