defmodule FleetmsWeb.VehicleLive.List do
  use FleetmsWeb, :live_view
  import Fleetms.Utils, only: [calc_total_pages: 2]

  @per_page_opts ["10", "15", "20", "30", "50", "75", "100", "150"]
  @sort_by_opts [
    name: "Name",
    vehicle_make: "Make",
    model: "Model",
    type: "Type",
    created_at: "Date Created",
    updated_at: "Date Updated",
    year: "Year",
    mileage: "Mileage"
  ]
  @sort_order [asc: "Ascending", desc: "Descending"]

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

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    pagination_params =
      Fleetms.Vehicles.Vehicle.validate_pagination_params!(params)

    sort_params =
      Fleetms.Vehicles.Vehicle.validate_sorting_params!(params)

    search_query = Map.get(params, "search_query", "")

    filter_form_data = filter_form_data_from_url_params(params)

    paginate_sort_opts = Map.merge(pagination_params, sort_params)

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:filter_form_data, filter_form_data)
      |> start_async(:get_vehicles, fn ->
        list_vehicles(
          tenant: tenant,
          actor: actor,
          paginate_sort_opts: paginate_sort_opts,
          search_query: search_query,
          filter_form_data: filter_form_data
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

    # TODO: Initialize flowbite on client
    {:noreply, push_event(socket, "initFlowbiteJS", %{})}
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
      Fleetms.Vehicles.VehicleModel.list_by_vehicle_make!(vehicle_make,
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
      |> Map.merge(socket.assigns.filter_form_data)

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
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"vehicle_search" => vehicle_search}, socket) do
    search_params = %{search_query: vehicle_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.paginate_sort_opts)
      |> Map.merge(socket.assigns.filter_form_data)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Vehicles.Vehicle, :destroy}, actor)

    if can_perform_action? do
      vehicle = Fleetms.Vehicles.Vehicle.get_by_id!(id, tenant: tenant, actor: actor)

      Ash.destroy!(vehicle, tenant: tenant, actor: actor)

      socket =
        socket
        |> stream_delete(:vehicles, vehicle)
        |> put_flash(:info, "Vehicle was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp apply_action(socket, :edit, %{"id" => id} = _params) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Vehicles.Vehicle, :update}, actor)

    if can_perform_action? do
      vehicle = Fleetms.Vehicles.Vehicle.get_by_id!(id, tenant: tenant, actor: actor)

      socket
      |> assign(:page_title, "Edit Vehicle Details")
      |> assign(:vehicle, vehicle)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :add, _params) do
    actor = socket.assigns.current_user

    can_perform_action? =
      Ash.can?({Fleetms.Vehicles.Vehicle, :create}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Add Vehicle")
      |> assign(:vehicle, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
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

  defp list_vehicles(opts) do
    %{page: page, per_page: per_page} = opts[:paginate_sort_opts]

    Fleetms.Vehicles.Vehicle
    |> Ash.Query.for_read(:list, %{
      paginate_sort_opts: opts[:paginate_sort_opts],
      search_query: opts[:search_query],
      advanced_filter_params: opts[:filter_form_data]
    })
    |> Ash.read!(
      tenant: opts[:tenant],
      actor: opts[:actor],
      page: [limit: per_page, offset: (page - 1) * per_page, count: true]
    )
  end

  defp filter_form_data_from_url_params(url_params) do
    default_params = %{
      mileage_min: 0,
      mileage_max: 999_999_999,
      year_from: 1970,
      year_to: 2030,
      type: :All,
      status: :All,
      category: :All,
      make: :All,
      model: :All
    }

    params =
      Map.take(url_params, [
        "mileage_min",
        "mileage_max",
        "year_to",
        "year_from",
        "type",
        "status",
        "category",
        "vehicle_make",
        "model"
      ])

    FleetmsWeb.VehicleLive.FilterFormComponent.build_filter_changeset(%{}, params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, validated_filter_params} ->
        validated_filter_params

      {:error, _changeset} ->
        default_params
    end
  end

  defp get_items_per_page_opts, do: @per_page_opts
  defp get_sort_by_opts, do: @sort_by_opts
  defp get_sort_order_opts, do: @sort_order
end
