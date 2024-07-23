defmodule FleetmsWeb.IssueLive.Index do
  use FleetmsWeb, :live_view

  import Fleetms.Utils, only: [calc_total_pages: 2, dates_in_map_to_string: 2]

  @per_page_opts ["10", "15", "20", "30", "50", "75", "100", "150"]
  @sort_by_opts [
    title: "Title",
    issue_number: "Issue Number",
    mileage: "Mileage",
    date_reported: "Date Reported",
    due_date: "Due Date",
    priority: "Priority",
    status: "Status",
    created_at: "Date Created",
    updated_at: "Date Updated"
  ]
  @sort_order [asc: "Ascending", desc: "Descending"]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_link, :issues)
      |> stream(:issues, [])
      |> assign(:total, 0)
      |> assign(:total_pages, 0)
      |> assign(:search_params, %{search_query: ""})
      |> assign(:has_more?, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    pagination_params =
      Fleetms.Issues.Issue.validate_pagination_params!(params)

    sort_params =
      Fleetms.Issues.Issue.validate_sorting_params!(params)

    search_query = Map.get(params, "search_query", "")

    filter_form_data = filter_form_data_from_url_params(params)

    filter_form_data_with_string_dates =
      filter_form_data
      |> dates_in_map_to_string([
        :date_reported_from,
        :date_reported_to,
        :due_date_from,
        :due_date_to
      ])

    paginate_sort_opts = Map.merge(pagination_params, sort_params)

    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:filter_form_data, filter_form_data_with_string_dates)
      |> start_async(:get_issues, fn ->
        list_issues(
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
  def handle_async(:get_issues, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:issues, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))

    # TODO: Initialize flowbite on client
    {:noreply, push_event(socket, "initFlowbiteJS", %{})}
  end

  @impl true
  def handle_async(:get_issues, {:exit, _reason}, socket) do
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

    {:noreply, push_patch(socket, to: ~p"/issues?#{new_url_params}")}
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

    {:noreply, push_patch(socket, to: ~p"/issues?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/issues?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"issue_search" => issue_search}, socket) do
    search_params = %{search_query: issue_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.paginate_sort_opts)
      |> Map.merge(socket.assigns.filter_form_data)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/issues?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    issue = Fleetms.Issues.Issue.get_by_id!(id, tenant: tenant, actor: actor)

    Ash.destroy!(issue, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream_delete(:issues, issue)
      |> put_flash(:info, "Issue was deleted successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_event("reopen_issue", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Issues.Issue, :update}, socket.assigns.current_user)

    if can_perform_action? do
      updated_issue =
        Fleetms.Issues.Issue.get_by_id!(id, tenant: tenant, actor: actor)
        |> Ash.Changeset.for_update(:reopen_issue)
        |> Ash.update!(tenant: tenant, actor: actor)

      socket =
        stream_insert(socket, :issues, updated_issue)
        |> put_flash(:info, "Issue ##{updated_issue.issue_number} was reopened!")

      {:noreply, socket}
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Issues.Issue, :update}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Edit Issue")
      |> assign(:issue, Fleetms.Issues.Issue.get_by_id!(id, tenant: tenant, actor: actor))
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :resolve_issue_with_comment, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Issues.Issue, :update}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Resolve Issue with Comment")
      |> assign(:issue, Fleetms.Issues.Issue.get_by_id!(id, tenant: tenant, actor: actor))
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :close_issue, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    can_perform_action? =
      Ash.can?({Fleetms.Issues.Issue, :update}, actor)

    if can_perform_action? do
      socket
      |> assign(:page_title, "Close Issue")
      |> assign(:issue, Fleetms.Issues.Issue.get_by_id!(id, tenant: tenant, actor: actor))
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Advanced Issue Filter Form")
  end

  defp apply_action(socket, :new, _params) do
    can_perform_action? =
      Ash.can?({Fleetms.Issues.Issue, :create}, socket.assigns.current_user)

    if can_perform_action? do
      socket
      |> assign(:page_title, "New Issue")
      |> assign(:issue, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Issues")
    |> assign(:issue, nil)
  end

  @impl true
  def handle_info({FleetmsWeb.IssueLive.FormComponent, {:saved, issue}}, socket) do
    {:noreply, stream_insert(socket, :issues, issue)}
  end

  defp list_issues(opts) do
    %{page: page, per_page: per_page} = opts[:paginate_sort_opts]

    Fleetms.Issues.Issue
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
      date_reported_from: ~D[1970-01-01],
      date_reported_to: Date.utc_today(),
      due_date_from: ~D[1970-01-01],
      due_date_to: Date.utc_today(),
      status: :All,
      priority: :All,
      vehicle_id: "All",
      reported_by: "All"
    }

    params =
      Map.take(url_params, [
        "mileage_min",
        "mileage_max",
        "date_reported_from",
        "date_reported_to",
        "due_date_from",
        "due_date_to",
        "status",
        "vehicle_id",
        "priority",
        "reported_by"
      ])

    FleetmsWeb.IssueLive.FilterFormComponent.build_filter_changeset(%{}, params)
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
