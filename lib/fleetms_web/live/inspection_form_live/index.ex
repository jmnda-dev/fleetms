defmodule FleetmsWeb.InspectionFormLive.Index do
  @moduledoc """
  Lists an organization's inspection form templates. Rows open the form in the
  builder; the status badge reflects the draft/active/archived lifecycle and the
  version count shows how many times a form has been published. Supports search, a
  status filter, sortable columns and pagination — all list state in the URL.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Inspections
  alias Fleetms.Scope

  @limit 20
  @sortable ~w(title status updated_at inserted_at)a
  @statuses ~w(draft active archived)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Inspection Forms"), active_link: :inspections)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    sort_by = sort_by(params["sort"], @sortable, :updated_at)
    sort_order = sort_order(params["dir"])
    filters = parse_filters(params)
    page = page_number(params["page"])

    result =
      Inspections.list_inspection_forms(
        %{search_query: query, filters: filters, sort_by: sort_by, sort_order: sort_order},
        scope: scope,
        page: [limit: @limit, offset: (page - 1) * @limit, count: true]
      )

    socket =
      case result do
        {:ok, data} ->
          assign(socket,
            forms: data.results,
            count: data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            sort_by: sort_by,
            sort_order: sort_order,
            filters: filters,
            statuses: @statuses,
            templates: Inspections.Templates.all(),
            can_create: Scope.has_permission?(scope, :create_inspection_form),
            can_delete: Scope.has_permission?(scope, :delete_inspection_form)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to inspection forms here."))
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
        %{label: gettext("Inspection Forms")}
      ]} />

      <.header>
        {gettext("Inspection Forms")}
        <:subtitle>
          {gettext("Reusable templates drivers and technicians fill out during an inspection.")}
        </:subtitle>
        <:actions>
          <div :if={@can_create} class="relative">
            <.button
              type="button"
              variant="secondary"
              id="templateMenuButton"
              data-dropdown-toggle="templateMenu"
            >
              <.icon name="fa-layer-group" class="me-2" /> {gettext("New from template")}
              <.icon name="fa-chevron-down" class="ms-2 text-xs" />
            </.button>
            <div
              id="templateMenu"
              class="z-50 hidden w-80 rounded-lg bg-white shadow-sm ring-1 ring-black/5 dark:bg-gray-700 dark:ring-white/10"
            >
              <ul class="divide-y divide-gray-100 py-1 dark:divide-gray-600">
                <li :for={template <- @templates}>
                  <button
                    type="button"
                    phx-click="from_template"
                    phx-value-key={template.key}
                    class="block w-full px-4 py-2.5 text-left hover:bg-gray-100 dark:hover:bg-gray-600"
                  >
                    <span class="block text-sm font-medium text-heading">{template.title}</span>
                    <span class="block text-xs text-body">{template.description}</span>
                  </button>
                </li>
              </ul>
            </div>
          </div>
          <.button :if={@can_create} navigate={~p"/o/#{org(assigns)}/inspection-forms/new"}>
            <.icon name="fa-plus" class="me-2" /> {gettext("New form")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          query={@query}
          filter_count={map_size(@filters)}
          drawer_id="form-filters"
          placeholder={gettext("Search forms…")}
        />

        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <.sort_th
                  label={gettext("Title")}
                  field="title"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Status")}
                  field="status"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Versions")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={form <- @forms}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, form)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {form.title}
                </th>
                <td phx-click={row_navigate(assigns, form)} class="cursor-pointer px-4 py-3">
                  <.status_badge status={form.status} />
                </td>
                <td phx-click={row_navigate(assigns, form)} class="cursor-pointer px-4 py-3">
                  {form.version_count}
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/inspection-forms/#{form.id}/build"}
                    >
                      {gettext("Open builder")}
                    </.button>
                    <.button
                      :if={@can_create}
                      size="xs"
                      variant="secondary"
                      phx-click="duplicate"
                      phx-value-id={form.id}
                    >
                      {gettext("Duplicate")}
                    </.button>
                    <.button
                      :if={@can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="delete"
                      phx-value-id={form.id}
                      data-confirm={gettext("Delete this form and all its versions?")}
                    >
                      {gettext("Delete")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@forms == []}>
                <td colspan="4" class="px-4 py-6">
                  <.empty_state
                    icon="fa-file-lines"
                    title={gettext("No inspection forms found")}
                    message={gettext("Build a form (e.g. a DVIR) for your team to fill out.")}
                  >
                    <.button
                      :if={@can_create}
                      navigate={~p"/o/#{org(assigns)}/inspection-forms/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New form")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer id="form-filters">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Status")}</span>
          <div class="space-y-2">
            <label :for={st <- @statuses} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="status[]"
                value={st}
                checked={st in (@filters["statuses"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {String.capitalize(st)}
            </label>
          </div>
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
        sort_by(by, @sortable, :updated_at)
      )

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    {:noreply,
     push_patch(socket,
       to: index_path(socket, %{"status" => params["status"] || [], "page" => nil})
     )}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/o/#{org(socket)}/inspection-forms?#{prune(%{"q" => socket.assigns.query})}"
     )}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("duplicate", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, source} <- Inspections.get_inspection_form(id, scope: scope),
         attrs = %{
           title: free_title(socket.assigns.forms, "#{source.title} (copy)"),
           description: source.description,
           labels: source.labels,
           draft_schema: source.draft_schema
         },
         {:ok, form} <- Inspections.duplicate_inspection_form(attrs, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Form duplicated. Edit and publish the copy."))
       |> push_navigate(to: ~p"/o/#{org(socket)}/inspection-forms/#{form.id}/build")}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not duplicate that form."))}
    end
  end

  def handle_event("from_template", %{"key" => key}, socket) do
    scope = socket.assigns.current_scope

    case Inspections.Templates.get(key) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("That template is not available."))}

      template ->
        attrs = %{
          title: free_title(socket.assigns.forms, template.title),
          description: template.description,
          draft_schema: template.schema
        }

        case Inspections.duplicate_inspection_form(attrs, scope: scope) do
          {:ok, form} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Form created from template. Edit and publish it."))
             |> push_navigate(to: ~p"/o/#{org(socket)}/inspection-forms/#{form.id}/build")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Could not create the form."))}
        end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, form} <- Inspections.get_inspection_form(id, scope: scope),
         :ok <- Inspections.delete_inspection_form(form, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Inspection form deleted."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that form."))}
    end
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded px-2 py-0.5 text-xs font-medium",
      @status == :draft && "bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-200",
      @status == :active && "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
      @status == :archived && "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"
    ]}>
      {Phoenix.Naming.humanize(@status)}
    </span>
    """
  end

  defp index_path(socket, overrides) do
    params =
      %{
        "q" => socket.assigns.query,
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "status" => socket.assigns.filters["statuses"] || []
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/inspection-forms?#{params}"
  end

  defp parse_filters(params) do
    %{"statuses" => Enum.filter(List.wrap(params["status"]), &(&1 in @statuses))}
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  # Picks a title not already used by a loaded form, appending " (2)", " (3)"… on a
  # clash, so duplicates and template forms don't hit the unique-title identity.
  defp free_title(forms, base) do
    titles = MapSet.new(forms, & &1.title)

    if MapSet.member?(titles, base) do
      Enum.find_value(2..999, base, fn n ->
        candidate = "#{base} (#{n})"
        if MapSet.member?(titles, candidate), do: false, else: candidate
      end)
    else
      base
    end
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  defp row_navigate(assigns, form),
    do: JS.navigate(~p"/o/#{org(assigns)}/inspection-forms/#{form.id}/build")
end
