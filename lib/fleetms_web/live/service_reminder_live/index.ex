defmodule FleetmsWeb.ServiceReminderLive.Index do
  use FleetmsWeb, :live_view

  import Fleetms.Utils,
    only: [calc_total_pages: 2, dates_in_map_to_string: 2, atom_list_to_options_for_select: 1]

  alias Fleetms.Common.PaginationSortParam
  alias Fleetms.Service

  @per_page_opts [10, 20, 30, 50, 100, 250, 500]
  @sort_by_opts [
    :service_group_name,
    :service_task_name,
    :mileage_interval,
    :time_interval,
    :due_status,
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
      |> assign(:active_link, :service_reminders)
      |> stream(:service_reminders, [])
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
        :next_due_date_from,
        :next_due_date_to
      ])

    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:filter_form_data, filter_form_data_with_string_dates)
      |> start_async(:get_service_reminders, fn ->
        list_service_reminders(
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
  def handle_async(:get_service_reminders, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:service_reminders, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))

    # TODO: Initialize flowbite on client
    {:noreply, push_event(socket, "initFlowbiteJS", %{})}
  end

  @impl true
  def handle_async(:get_service_reminders, {:exit, _reason}, socket) do
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

    {:noreply, push_patch(socket, to: ~p"/service_reminders?#{new_url_params}")}
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

    {:noreply, push_patch(socket, to: ~p"/service_reminders?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/service_reminders?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"service_reminder_search" => service_reminder_search}, socket) do
    search_params = %{search_query: service_reminder_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.paginate_sort_opts)
      |> Map.merge(socket.assigns.filter_form_data)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/service_reminders?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    service_reminder =
      Fleetms.Service.ServiceReminder.get_by_id!(id, tenant: tenant, actor: actor)

    Ash.destroy!(service_reminder, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream_delete(:service_reminders, service_reminder)
      |> put_flash(
        :info,
        "Reminder was deleted successfully"
      )

    {:noreply, socket}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Service.ServiceReminder, :update}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Edit Service Reminder")
      |> assign(
        :service_reminder,
        Fleetms.Service.ServiceReminder.get_for_form!(id, tenant: tenant, actor: actor)
      )
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :new, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.Service.ServiceReminder, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      socket
      |> assign(:page_title, "New Service Reminder")
      |> assign(:service_reminder, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Service Reminders")
    |> assign(:service_reminder, nil)
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Advanced Service Reminder Filter Form")
  end

  @impl true
  def handle_info(
        {FleetmsWeb.ServiceReminderLive.FormComponent, {:saved, service_reminder}},
        socket
      ) do
    {:noreply, stream_insert(socket, :service_reminders, service_reminder)}
  end

  defp list_service_reminders(paginate_sort_opts, search_query, filter_form_data, opts) do
    %{page: page, per_page: per_page} = paginate_sort_opts

    Service.list_service_reminders!(paginate_sort_opts, search_query, filter_form_data,
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
      mileage_interval_min: 0,
      mileage_interval_max: 999_999_999,
      mileage_next_due_min: 0,
      mileage_next_due_max: 999_999_999,
      time_interval_min: 0,
      time_interval_max: 12,
      time_interval_unit: :years,
      next_due_date_from: ~D[1970-01-01],
      next_due_date_to: Timex.shift(Date.utc_today(), years: 5),
      due_statuses: [],
      service_groups: [],
      vehicles: [],
      service_tasks: []
    }

    params =
      Map.take(url_params, [
        "mileage_interval_min",
        "mileage_interval_max",
        "mileage_next_due_min",
        "mileage_next_due_max",
        "time_interval_min",
        "time_interval_max",
        "time_interval_unit",
        "next_due_date_from",
        "next_due_date_to",
        "due_statuses",
        "vehicles",
        "service_groups",
        "service_tasks"
      ])

    FleetmsWeb.ServiceReminderLive.FilterFormComponent.build_filter_changeset(%{}, params)
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
