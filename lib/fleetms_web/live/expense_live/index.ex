defmodule FleetmsWeb.ExpenseLive.Index do
  @moduledoc """
  Lists an organization's vehicle expenses with free-text search, a filter drawer
  (category, vehicle, date range), sortable columns and pagination, plus an archived
  view. Each amount shows in its own currency. All list state lives in the URL.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Expenses
  alias Fleetms.Expenses.ExpenseCategory
  alias Fleetms.Format
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  @limit 20
  @sortable ~w(expense_date amount category inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Expenses"), active_link: :expenses)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    archived? = params["archived"] == "1"
    sort_by = sort_by(params["sort"], @sortable, :expense_date)
    sort_order = sort_order(params["dir"])
    filters = parse_filters(params)
    page = page_number(params["page"])

    args = %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order}
    opts = [scope: scope, page: [limit: @limit, offset: (page - 1) * @limit, count: true]]

    result =
      if archived? do
        Expenses.list_archived_expenses(%{search_query: query}, opts)
      else
        Expenses.list_expenses(args, opts)
      end

    socket =
      case result do
        {:ok, data} ->
          assign(socket,
            expenses: data.results,
            count: data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            categories: ExpenseCategory.values(),
            vehicles: vehicle_options(scope),
            can_create: Scope.has_permission?(scope, :create_expense),
            can_update: Scope.has_permission?(scope, :update_expense),
            can_delete: Scope.has_permission?(scope, :delete_expense)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to expenses here."))
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
        %{label: gettext("Expenses")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived expenses"), else: gettext("Expenses")}
        <:subtitle>
          {if @archived_view,
            do: gettext("%{count} archived", count: @count),
            else: gettext("%{count} recorded", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/expenses/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New expense")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          :if={not @archived_view}
          query={@query}
          filter_count={map_size(@filters)}
          drawer_id="expense-filters"
          placeholder={gettext("Search vehicle or description…")}
        />
        <div :if={@archived_view} class="border-b border-default p-4">
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
                placeholder={gettext("Search vehicle or description…")}
                class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand"
              />
            </div>
          </form>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <.sort_th
                  label={gettext("Date")}
                  field="expense_date"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <.sort_th
                  label={gettext("Category")}
                  field="category"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Description")}</th>
                <.sort_th
                  label={gettext("Amount")}
                  field="amount"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                  class="text-right"
                />
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={expense <- @expenses}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, expense)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {Format.date(expense.expense_date, org(assigns))}
                </th>
                <td phx-click={row_navigate(assigns, expense)} class="cursor-pointer px-4 py-3">
                  {expense.vehicle && expense.vehicle.name}
                </td>
                <td phx-click={row_navigate(assigns, expense)} class="cursor-pointer px-4 py-3">
                  <.badge>{humanize(expense.category)}</.badge>
                </td>
                <td
                  phx-click={row_navigate(assigns, expense)}
                  class="max-w-xs cursor-pointer truncate px-4 py-3"
                >
                  {expense.description}
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-right font-medium text-heading">
                  {fmt_money(expense.amount)}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={expense.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/expenses/#{expense.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={expense.id}
                      data-confirm={gettext("Archive this expense? You can restore it later.")}
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@expenses == []}>
                <td colspan="6" class="px-4 py-6">
                  <.empty_state
                    icon="fa-receipt"
                    title={
                      if @archived_view,
                        do: gettext("No archived expenses"),
                        else: gettext("No expenses found")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Log insurance, registration, tolls and other vehicle costs.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/expenses/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New expense")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer :if={not @archived_view} id="expense-filters">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Category")}</span>
          <div class="grid grid-cols-2 gap-2">
            <label :for={c <- @categories} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="category[]"
                value={c}
                checked={to_string(c) in (@filters["categories"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {humanize(c)}
            </label>
          </div>
        </div>

        <.search_select
          id="filter_exp_vehicle_id"
          name="vehicle_id"
          value={@filters["vehicle_id"]}
          label={gettext("Vehicle")}
          prompt={gettext("Any vehicle")}
          options={@vehicles}
        />

        <div class="grid grid-cols-2 gap-3">
          <.date_input
            id="filter_exp_from"
            name="from"
            value={@filters["from"]}
            label={gettext("From")}
          />
          <.date_input id="filter_exp_to" name="to" value={@filters["to"]} label={gettext("To")} />
        </div>
      </.filter_drawer>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"q" => nilify(q), "page" => nil}))}
  end

  def handle_event("sort", %{"by" => by}, socket) do
    {sort, dir} =
      next_sort(
        socket.assigns.sort_by,
        socket.assigns.sort_order,
        sort_by(by, @sortable, :expense_date)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    overrides = %{
      "category" => params["category"] || [],
      "vehicle_id" => nilify(params["vehicle_id"]),
      "from" => nilify(params["from"]),
      "to" => nilify(params["to"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/o/#{org(socket)}/expenses?#{prune(%{"q" => socket.assigns.query})}"
     )}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, expense} <- Expenses.get_expense(id, scope: scope),
         :ok <- Expenses.delete_expense(expense, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Expense archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that expense."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with expense when not is_nil(expense) <- Enum.find(socket.assigns.expenses, &(&1.id == id)),
         {:ok, _} <- Expenses.restore_expense(expense, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Expense restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that expense."))}
    end
  end

  # --- URL <-> state ---

  defp index_path(socket, overrides) do
    f = socket.assigns.filters

    params =
      %{
        "q" => socket.assigns.query,
        "archived" => if(socket.assigns.archived_view, do: "1"),
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "category" => f["categories"] || [],
        "vehicle_id" => f["vehicle_id"],
        "from" => f["from"],
        "to" => f["to"]
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/expenses?#{params}"
  end

  defp parse_filters(params) do
    valid = Enum.map(ExpenseCategory.values(), &to_string/1)

    %{
      "categories" => Enum.filter(List.wrap(params["category"]), &(&1 in valid)),
      "vehicle_id" => nilify(params["vehicle_id"]),
      "from" => nilify(params["from"]),
      "to" => nilify(params["to"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/expenses"
    else
      ~p"/o/#{org(assigns)}/expenses?#{%{"archived" => "1"}}"
    end
  end

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp row_navigate(%{archived_view: true}, _expense), do: nil

  defp row_navigate(assigns, expense),
    do: JS.navigate(~p"/o/#{org(assigns)}/expenses/#{expense.id}/edit")

  defp fmt_money(nil), do: "—"
  defp fmt_money(money), do: Money.to_string!(money)

  defp humanize(value),
    do: value |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
