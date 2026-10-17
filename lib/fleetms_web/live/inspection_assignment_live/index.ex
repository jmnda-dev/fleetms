defmodule FleetmsWeb.InspectionAssignmentLive.Index do
  @moduledoc """
  The "what's due" list: inspection assignments produced by schedules, with their
  live status (pending / overdue / done). The open / assigned-to-me / all tabs filter
  the list; the Due column sorts and the list paginates. Open items link straight
  into the fill flow with the form and vehicle preselected. All list state lives in
  the URL.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Inspections
  alias Fleetms.Scope

  @limit 20
  @filters ~w(open mine all)a
  @sortable ~w(due_on completed_at inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Due Inspections"),
       active_link: :inspections,
       filter: :open
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = parse_filter(params["filter"])
    sort_by = sort_by(params["sort"], @sortable, :due_on)
    sort_order = sort_order(params["dir"] || "asc")
    page = page_number(params["page"])

    {:noreply,
     socket
     |> assign(
       filter: filter,
       sort_by: sort_by,
       sort_order: sort_order,
       page: page,
       limit: @limit
     )
     |> load_assignments()}
  end

  defp load_assignments(socket) do
    scope = socket.assigns.current_scope

    base =
      case socket.assigns.filter do
        :open -> %{only_open: true}
        :mine -> %{assigned_to_id: scope.user.id}
        :all -> %{}
      end

    args =
      Map.merge(base, %{sort_by: socket.assigns.sort_by, sort_order: socket.assigns.sort_order})

    case Inspections.list_inspection_assignments(args,
           scope: scope,
           page: [
             limit: @limit,
             offset: (socket.assigns.page - 1) * @limit,
             count: true
           ],
           load: [assigned_to: [:email, profile: [:first_name, :last_name]]]
         ) do
      {:ok, page} ->
        assign(socket,
          assignments: page.results,
          count: page.count || 0,
          can_fill: Scope.has_permission?(scope, :fill_inspections)
        )

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("You don't have access to inspection assignments here."))
        |> assign(assignments: [], count: 0, can_fill: false)
    end
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
        %{label: gettext("Due Inspections")}
      ]} />

      <.header>
        {gettext("Due Inspections")}
        <:subtitle>{gettext("Inspections scheduled to be filled, and their status.")}</:subtitle>
      </.header>

      <div class="mt-4 flex gap-1">
        <.link
          :for={
            {key, label} <- [
              open: gettext("Open"),
              mine: gettext("Assigned to me"),
              all: gettext("All")
            ]
          }
          patch={tab_path(assigns, key)}
          class={[
            "rounded-lg px-3 py-1.5 text-sm font-medium",
            @filter == key && "bg-brand text-white dark:text-primary-900",
            @filter != key &&
              "text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700"
          ]}
        >
          {label}
        </.link>
      </div>

      <div class="mt-4 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Form")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Vehicle")}</th>
                <.sort_th
                  label={gettext("Due")}
                  field="due_on"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Assignee")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={assignment <- @assignments}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <td class="px-4 py-3 font-medium text-heading">{assignment.inspection_form.title}</td>
                <td class="whitespace-nowrap px-4 py-3">{assignment.vehicle.name}</td>
                <td class="whitespace-nowrap px-4 py-3">
                  {Calendar.strftime(assignment.due_on, "%Y-%m-%d")}
                </td>
                <td class="whitespace-nowrap px-4 py-3">{assignee_name(assignment.assigned_to)}</td>
                <td class="px-4 py-3"><.status_badge status={assignment.status} /></td>
                <td class="px-4 py-3 text-right">
                  <.button
                    :if={@can_fill and assignment.status != :done}
                    size="xs"
                    navigate={
                      ~p"/o/#{org(assigns)}/inspections/new?#{%{form_id: assignment.inspection_form_id, vehicle_id: assignment.vehicle_id}}"
                    }
                  >
                    {gettext("Fill")}
                  </.button>
                  <.button
                    :if={assignment.status == :done and assignment.inspection_id}
                    size="xs"
                    variant="secondary"
                    navigate={~p"/o/#{org(assigns)}/inspections/#{assignment.inspection_id}"}
                  >
                    {gettext("View")}
                  </.button>
                </td>
              </tr>
              <tr :if={@assignments == []}>
                <td colspan="6" class="px-4 py-6">
                  <.empty_state
                    icon="fa-clock"
                    title={gettext("Nothing due")}
                    message={gettext("Inspections that come due will appear here.")}
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("sort", %{"by" => by}, socket) do
    {sort, dir} =
      next_sort(
        socket.assigns.sort_by,
        socket.assigns.sort_order,
        sort_by(by, @sortable, :due_on)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded px-2 py-0.5 text-xs font-medium",
      @status == :pending && "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300",
      @status == :overdue && "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300",
      @status == :done && "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300"
    ]}>
      {Phoenix.Naming.humanize(@status)}
    </span>
    """
  end

  defp index_path(socket, overrides) do
    params =
      %{
        "filter" => to_string(socket.assigns.filter),
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page)
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/inspection-assignments?#{params}"
  end

  # A tab switch keeps the current sort but resets to page 1.
  defp tab_path(assigns, key) do
    params =
      prune(%{
        "filter" => to_string(key),
        "sort" => to_string(assigns.sort_by),
        "dir" => to_string(assigns.sort_order)
      })

    ~p"/o/#{org(assigns)}/inspection-assignments?#{params}"
  end

  defp assignee_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp assignee_name(%{email: email}), do: to_string(email)
  defp assignee_name(_), do: "—"

  defp parse_filter(value) when is_binary(value) do
    atom = String.to_existing_atom(value)
    if atom in @filters, do: atom, else: :open
  rescue
    ArgumentError -> :open
  end

  defp parse_filter(_), do: :open

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
