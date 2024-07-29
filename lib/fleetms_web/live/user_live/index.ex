defmodule FleetmsWeb.UserLive.Index do
  use FleetmsWeb, :live_view

  import Fleetms.Utils, only: [calc_total_pages: 2, atom_list_to_options_for_select: 1]

  alias Fleetms.Accounts
  alias Fleetms.Accounts.User
  alias Fleetms.Common.PaginationSortParam

  @per_page_opts [10, 20, 30, 50, 100, 250, 500]
  @sort_by_opts [
    :created_at,
    :updated_at,
    :first_name,
    :last_name
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
    if not Ash.can?({User, :list}, socket.assigns.current_user) do
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end

    socket =
      socket
      |> assign(:active_link, :users_list)
      |> stream(:users, [])
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

    %{current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:filter_form_data, filter_form_data)
      |> start_async(:get_users, fn ->
        list_users(
          paginate_sort_opts,
          search_query,
          filter_form_data,
          actor: actor
        )
      end)

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_async(:get_users, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:users, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))

    # TODO: Initialize flowbite on client
    {:noreply, push_event(socket, "initFlowbiteJS", %{})}
  end

  @impl true
  def handle_async(:get_users, {:error, _reason}, socket) do
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

    {:noreply, push_patch(socket, to: ~p"/users?#{new_url_params}")}
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

    {:noreply, push_patch(socket, to: ~p"/users?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/users?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"user_search" => user_search}, socket) do
    search_params = %{search_query: user_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.filter_form_data)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/users?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{current_user: actor} = socket.assigns
    user = Accounts.get_user_by_id!(id, actor: actor)

    Ash.destroy!(user, actor: actor)

    socket =
      socket
      |> stream_delete(:users, user)
      |> put_flash(:info, "#{user.name} was deleted successfully")

    {:noreply, socket}
  end

  @impl true
  def handle_info({FleetmsWeb.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{current_user: actor} = socket.assigns

    if Ash.can?({User, :update}, actor) do
      user = Accounts.get_user_by_id!(id, actor: actor)

      socket
      |> assign(:page_title, "Edit User")
      |> assign(:user, user)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Listing Users")
  end

  defp apply_action(socket, :new, _params) do
    if Ash.can?({User, :create_organization_user}, socket.assigns.current_user) do
      socket
      |> assign(:page_title, "Add User ")
      |> assign(:user, nil)
    else
      raise FleetmsWeb.Plug.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Users")
    |> assign(:user, nil)
  end

  defp list_users(paginate_sort_opts, search_query, filter_form_data, opts) do
    %{page: page, per_page: per_page} = paginate_sort_opts

    Accounts.list_users!(paginate_sort_opts, search_query, filter_form_data,
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
    params =
      Map.take(url_params, [
        "roles",
        "status"
      ])

    FleetmsWeb.UserLive.FilterFormComponent.build_filter_changeset(%{}, params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, validated_filter_params} ->
        validated_filter_params

      {:error, _changeset} ->
        %{roles: [], status: []}
    end
  end

  defp get_items_per_page_opts, do: @per_page_opts
  defp get_sort_by_opts, do: atom_list_to_options_for_select(@sort_by_opts)
  defp get_sort_order_opts, do: atom_list_to_options_for_select(@sort_order)
end
