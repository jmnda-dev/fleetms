defmodule FleetmsWeb.VehicleAssignmentLive.Index do
  use FleetmsWeb, :live_view
  import Fleetms.Utils, only: [calc_total_pages: 2, dates_in_map_to_string: 2]

  @per_page_opts ["10", "15", "20", "30", "50", "75", "100", "150"]
  @sort_by_opts [
    start_datetime: "Start Datetime",
    end_datetime: "End Datetime",
    start_mileage: "Start Mileage",
    end_mileage: "End Mileage",
    created_at: "Date Created",
    updated_at: "Date Updated",
    status: "Status"
  ]
  @sort_order [asc: "Ascending", desc: "Descending"]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_link, :vehicle_assignments)
      |> stream(:vehicle_assignments, [])
      |> assign(:total, 0)
      |> assign(:total_pages, 0)
      |> assign(:search_params, %{search_query: ""})
      |> assign(:has_more?, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    pagination_params =
      Fleetms.Vehicles.VehicleAssignment.validate_pagination_params!(params)

    sort_params =
      Fleetms.Vehicles.VehicleAssignment.validate_sorting_params!(params)

    search_query = Map.get(params, "search_query", "")

    filter_form_data = filter_form_data_from_url_params(params)

    paginate_sort_opts = Map.merge(pagination_params, sort_params)

    parsed_filter_form_data =
      filter_form_data
      |> dates_in_map_to_string([:start_date_min, :start_date_max, :end_date_min, :end_date_max])

    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:filter_form_data, parsed_filter_form_data)
      |> start_async(:get_vehicle_assignments, fn ->
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
  def handle_async(:get_vehicle_assignments, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:vehicle_assignments, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))

    {:noreply, push_event(socket, "initFlowbiteJS", %{})}
  end

  @impl true
  def handle_async(:get_vehicle_assignments, {:exit, _reason}, socket) do
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

    {:noreply, push_patch(socket, to: ~p"/vehicle_assignments?#{new_url_params}")}
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

    {:noreply, push_patch(socket, to: ~p"/vehicle_assignments?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/vehicle_assignments?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"vehicle_assignment_search" => vehicle_search}, socket) do
    search_params = %{search_query: vehicle_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.paginate_sort_opts)
      |> Map.merge(socket.assigns.filter_form_data)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/vehicle_assignments?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Vehicles.VehicleAssignment, :destroy}, actor)

    if can_perform_action? do
      vehicle_assignment =
        Fleetms.Vehicles.VehicleAssignment.get_by_id!(id, tenant: tenant, actor: actor)

      Ash.destroy!(vehicle_assignment, tenant: tenant, actor: actor)

      socket =
        socket
        |> stream_delete(:vehicle_assignments, vehicle_assignment)
        |> put_flash(:info, "Vehicle Assignment was deleted successfully")

      {:noreply, socket}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("load_vehicle_assignment_detail", %{"id" => id} = _params, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicle_assignment =
      Fleetms.Vehicles.VehicleAssignment.get_by_id!(id, tenant: tenant, actor: actor)

    {:noreply, assign(socket, :vehicle_assignment, vehicle_assignment)}
  end

  defp apply_action(socket, :edit, %{"id" => id} = _params) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Vehicles.VehicleAssignment, :update}, actor)

    if can_perform_action? do
      vehicle_assignment =
        Fleetms.Vehicles.VehicleAssignment.get_by_id!(id, tenant: tenant, actor: actor)

      socket
      |> assign(:page_title, "Edit Vehicle Assignment Details")
      |> assign(:vehicle_assignment, vehicle_assignment)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :new, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Vehicles.VehicleAssignment, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      socket
      |> assign(:page_title, "Add Vehicle Assignment")
      |> assign(:vehicle_assignment, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Advanced Vehicle Assignment Filter Form")
    |> assign(:vehicle_assignment, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Vehicle Assignment Listing")
    |> assign(:form, nil)
    |> assign(:vehicle_assignment, nil)
  end

  defp list_vehicles(opts) do
    %{page: page, per_page: per_page} = opts[:paginate_sort_opts]

    Fleetms.Vehicles.VehicleAssignment
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
    params =
      Map.take(url_params, [
        "statuses",
        "start_mileage_min",
        "start_mileage_max",
        "end_mileage_min",
        "end_mileage_max",
        "start_date_min",
        "start_date_max",
        "end_date_min",
        "end_date_max",
        "vehicles",
        "assignees"
      ])

    FleetmsWeb.VehicleAssignmentLive.FilterFormComponent.build_filter_changeset(%{}, params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, validated_filter_params} ->
        validated_filter_params

      {:error, _changeset} ->
        %{}
    end
  end

  defp get_items_per_page_opts, do: @per_page_opts
  defp get_sort_by_opts, do: @sort_by_opts
  defp get_sort_order_opts, do: @sort_order
end
