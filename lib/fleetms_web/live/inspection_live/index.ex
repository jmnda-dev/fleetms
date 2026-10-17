defmodule FleetmsWeb.InspectionLive.Index do
  @moduledoc """
  Lists submitted inspections with their vehicle, form, result and failure count.
  Supports free-text search, a filter drawer (result, vehicle, form), sortable
  columns and pagination, plus an archived view. All list state lives in the URL.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Format
  alias Fleetms.Inspections
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement

  @limit 20
  @sortable ~w(submitted_at result status inserted_at)a
  @results ~w(passed failed pending)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Inspections"), active_link: :inspections)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    archived? = params["archived"] == "1"
    sort_by = sort_by(params["sort"], @sortable, :submitted_at)
    sort_order = sort_order(params["dir"])
    filters = parse_filters(params)
    page = page_number(params["page"])

    args = %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order}
    opts = [scope: scope, page: [limit: @limit, offset: (page - 1) * @limit, count: true]]

    result =
      if archived? do
        Inspections.list_archived_inspections(args, opts)
      else
        Inspections.list_inspections(args, opts)
      end

    socket =
      case result do
        {:ok, data} ->
          assign(socket,
            inspections: data.results,
            count: data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            archived_view: archived?,
            results: @results,
            vehicles: vehicle_options(scope),
            forms: form_options(scope),
            can_create: Scope.has_permission?(scope, :fill_inspections),
            can_delete: Scope.has_permission?(scope, :delete_inspection)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to inspections here."))
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
        %{label: gettext("Inspections")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived inspections"), else: gettext("Inspections")}
        <:subtitle>
          {if @archived_view,
            do: gettext("Archived inspections can be restored."),
            else: gettext("%{count} completed inspections.", count: @count)}
        </:subtitle>
        <:actions>
          <.button :if={@can_delete} variant="secondary" navigate={toggle_archived_path(assigns)}>
            <.icon
              name={if @archived_view, do: "fa-arrow-left-long", else: "fa-box-archive"}
              class="me-2"
            />
            {if @archived_view, do: gettext("Back to active"), else: gettext("Show archived")}
          </.button>
          <.button
            :if={@can_create and not @archived_view}
            navigate={~p"/o/#{org(assigns)}/inspections/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New inspection")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          query={@query}
          filter_count={map_size(@filters)}
          drawer_id="inspection-filters"
          placeholder={gettext("Search vehicle or form…")}
        />

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Form")}</th>
                <.sort_th
                  label={gettext("Result")}
                  field="result"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Submitted")}
                  field="submitted_at"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={inspection <- @inspections}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, inspection)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {inspection.vehicle.name}
                </th>
                <td phx-click={row_navigate(assigns, inspection)} class="cursor-pointer px-4 py-3">
                  {inspection.inspection_form && inspection.inspection_form.title}
                </td>
                <td phx-click={row_navigate(assigns, inspection)} class="cursor-pointer px-4 py-3">
                  <.result_badge result={inspection.result} failures={inspection.failure_count} />
                </td>
                <td phx-click={row_navigate(assigns, inspection)} class="cursor-pointer px-4 py-3">
                  {Format.datetime(inspection.submitted_at, org(assigns))}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_delete}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={inspection.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/inspections/#{inspection.id}"}
                    >
                      {gettext("View")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={inspection.id}
                      data-confirm={
                        gettext(
                          "Archive this inspection? You can restore it later from Show archived."
                        )
                      }
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@inspections == []}>
                <td colspan="5" class="px-4 py-6">
                  <.empty_state
                    icon="fa-clipboard-check"
                    title={
                      if @archived_view,
                        do: gettext("No archived inspections"),
                        else: gettext("No inspections found")
                    }
                    message={
                      unless @archived_view,
                        do: gettext("Fill out an inspection form against a vehicle.")
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/inspections/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Start inspection")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer id="inspection-filters">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Result")}</span>
          <div class="space-y-2">
            <label :for={r <- @results} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="result[]"
                value={r}
                checked={r in (@filters["results"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {String.capitalize(r)}
            </label>
          </div>
        </div>

        <.search_select
          id="filter_insp_vehicle_id"
          name="vehicle_id"
          value={@filters["vehicle_id"]}
          label={gettext("Vehicle")}
          prompt={gettext("Any vehicle")}
          options={@vehicles}
        />
        <.search_select
          id="filter_insp_form_id"
          name="inspection_form_id"
          value={@filters["inspection_form_id"]}
          label={gettext("Form")}
          prompt={gettext("Any form")}
          options={@forms}
        />
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
        sort_by(by, @sortable, :submitted_at)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    overrides = %{
      "result" => params["result"] || [],
      "vehicle_id" => nilify(params["vehicle_id"]),
      "inspection_form_id" => nilify(params["inspection_form_id"]),
      "page" => nil
    }

    {:noreply, push_patch(socket, to: index_path(socket, overrides))}
  end

  def handle_event("clear-filters", _params, socket) do
    base = %{"q" => socket.assigns.query, "archived" => archived_param(socket)}
    {:noreply, push_patch(socket, to: ~p"/o/#{org(socket)}/inspections?#{prune(base)}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, inspection} <- Inspections.get_inspection(id, scope: scope),
         :ok <- Inspections.delete_inspection(inspection, scope: scope) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext("Inspection archived. Restore it any time from Show archived.")
       )
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that inspection."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, inspection} <- Inspections.get_inspection(id, scope: scope),
         {:ok, _} <- Inspections.restore_inspection(inspection, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Inspection restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that inspection."))}
    end
  end

  # --- URL <-> state ---

  defp index_path(socket, overrides) do
    f = socket.assigns.filters

    params =
      %{
        "q" => socket.assigns.query,
        "archived" => archived_param(socket),
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "result" => f["results"] || [],
        "vehicle_id" => f["vehicle_id"],
        "inspection_form_id" => f["inspection_form_id"]
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/inspections?#{params}"
  end

  defp archived_param(socket), do: if(socket.assigns.archived_view, do: "1")

  defp parse_filters(params) do
    %{
      "results" => Enum.filter(List.wrap(params["result"]), &(&1 in @results)),
      "vehicle_id" => nilify(params["vehicle_id"]),
      "inspection_form_id" => nilify(params["inspection_form_id"])
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/inspections"
    else
      ~p"/o/#{org(assigns)}/inspections?#{%{"archived" => "1"}}"
    end
  end

  attr :result, :atom, required: true
  attr :failures, :integer, default: 0

  def result_badge(assigns) do
    ~H"""
    <span class={[
      "rounded px-2 py-0.5 text-xs font-medium",
      @result == :passed && "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
      @result == :failed && "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300",
      @result == :pending && "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-200"
    ]}>
      {Phoenix.Naming.humanize(@result)}
      <span :if={@result == :failed && @failures > 0}>· {@failures}</span>
    </span>
    """
  end

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp form_options(scope) do
    case Inspections.list_inspection_forms(%{}, scope: scope, page: [limit: 200, offset: 0]) do
      {:ok, page} -> Enum.map(page.results, &{&1.title, &1.id})
      _ -> []
    end
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(%{archived_view: true}, _inspection), do: nil

  defp row_navigate(assigns, inspection),
    do: JS.navigate(~p"/o/#{org(assigns)}/inspections/#{inspection.id}")
end
