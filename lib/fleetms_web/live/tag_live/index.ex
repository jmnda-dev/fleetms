defmodule FleetmsWeb.TagLive.Index do
  @moduledoc """
  Manage the organization's tag vocabulary: create a tag, rename or recolour an
  existing one, and delete tags. The list supports search, a colour filter, sortable
  columns and pagination, with all list state in the URL. Each row shows the tag's
  chip and how many records currently carry it; deleting a tag removes it from those
  records.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias AshPhoenix.Form
  alias Fleetms.Scope
  alias Fleetms.Tagging
  alias Fleetms.Tagging.Tag
  alias Fleetms.Tagging.TagColor

  @limit 20
  @sortable ~w(name color usage_count inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Tags"),
       active_link: :settings,
       color_options: color_options(),
       colors: Enum.map(TagColor.values(), &to_string/1),
       editing_id: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    if Scope.has_permission?(scope, :view_tags) do
      query = params["q"] || ""
      sort_by = sort_by(params["sort"], @sortable, :name)
      sort_order = sort_order(params["dir"] || "asc")
      filters = parse_filters(params)
      page = page_number(params["page"])

      {:noreply,
       socket
       |> assign(
         can_create: Scope.has_permission?(scope, :create_tag),
         can_update: Scope.has_permission?(scope, :update_tag),
         can_delete: Scope.has_permission?(scope, :delete_tags),
         query: query,
         sort_by: sort_by,
         sort_order: sort_order,
         filters: filters,
         page: page,
         limit: @limit,
         editing_id: nil,
         edit_form: nil
       )
       |> load_tags()
       |> assign_new_form()}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("You don't have access to tags here."))
       |> push_navigate(to: ~p"/o/#{scope.organization}")}
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
        %{label: gettext("Tags")}
      ]} />

      <.header>
        {gettext("Tags")}
        <:subtitle>
          {gettext("The labels you can attach to vehicles, issues, work orders and parts.")}
        </:subtitle>
      </.header>

      <div class="mt-6 max-w-3xl space-y-6">
        <section
          :if={@can_create}
          class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800"
        >
          <h2 class="mb-4 text-sm font-semibold uppercase text-heading">{gettext("Add a tag")}</h2>
          <.form
            :let={f}
            for={@new_form}
            id="new-tag-form"
            phx-change="validate_new"
            phx-submit="create"
            class="flex flex-col gap-3 sm:flex-row sm:items-end"
          >
            <div class="flex-1">
              <.input field={f[:name]} label={gettext("Name")} placeholder={gettext("e.g. warranty")} />
            </div>
            <div class="w-40">
              <.input
                field={f[:color]}
                type="select"
                label={gettext("Colour")}
                options={@color_options}
              />
            </div>
            <.button type="submit" phx-disable-with={gettext("Adding…")}>
              <.icon name="fa-plus" class="me-2" /> {gettext("Add")}
            </.button>
          </.form>
        </section>

        <section class="rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
          <.list_toolbar
            query={@query}
            filter_count={map_size(@filters)}
            drawer_id="tag-filters"
            placeholder={gettext("Search tags…")}
          />
          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm text-body">
              <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
                <tr>
                  <.sort_th
                    label={gettext("Tag")}
                    field="name"
                    sort_by={@sort_by}
                    sort_order={@sort_order}
                  />
                  <.sort_th
                    label={gettext("Used by")}
                    field="usage_count"
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
                  :for={tag <- @tags}
                  class="border-t border-default align-middle hover:bg-gray-50 dark:hover:bg-gray-700"
                >
                  <%= if @editing_id == tag.id do %>
                    <td colspan="3" class="px-4 py-3">
                      <.form
                        :let={f}
                        for={@edit_form}
                        id={"edit-tag-#{tag.id}"}
                        phx-change="validate_edit"
                        phx-submit="update"
                        class="flex flex-col gap-3 sm:flex-row sm:items-end"
                      >
                        <div class="flex-1">
                          <.input field={f[:name]} label={gettext("Name")} />
                        </div>
                        <div class="w-40">
                          <.input
                            field={f[:color]}
                            type="select"
                            label={gettext("Colour")}
                            options={@color_options}
                          />
                        </div>
                        <div class="flex gap-2">
                          <.button type="submit" phx-disable-with={gettext("Saving…")}>
                            {gettext("Save")}
                          </.button>
                          <.button type="button" variant="secondary" phx-click="cancel_edit">
                            {gettext("Cancel")}
                          </.button>
                        </div>
                      </.form>
                    </td>
                  <% else %>
                    <td class="px-4 py-3">
                      <.tag_list tags={[tag]} />
                    </td>
                    <td class="px-4 py-3">
                      {ngettext("1 record", "%{count} records", tag.usage_count)}
                    </td>
                    <td class="px-4 py-3">
                      <div class="flex items-center justify-end gap-1">
                        <.button
                          :if={@can_update}
                          size="xs"
                          variant="secondary"
                          phx-click="edit"
                          phx-value-id={tag.id}
                        >
                          <.icon name="fa-pen" class="me-1 text-xs" /> {gettext("Edit")}
                        </.button>
                        <.button
                          :if={@can_delete}
                          size="xs"
                          variant="danger"
                          phx-click="delete"
                          phx-value-id={tag.id}
                          data-confirm={delete_confirm(tag)}
                        >
                          <.icon name="fa-trash" class="me-1 text-xs" /> {gettext("Delete")}
                        </.button>
                      </div>
                    </td>
                  <% end %>
                </tr>
                <tr :if={@tags == []}>
                  <td colspan="3" class="px-4 py-6">
                    <.empty_state
                      icon="fa-tags"
                      title={gettext("No tags found")}
                      message={gettext("Add one above, or type a new tag on any record.")}
                    />
                  </td>
                </tr>
              </tbody>
            </table>

            <.list_pagination count={@count} page={@page} limit={@limit} />
          </div>
        </section>
      </div>

      <.filter_drawer id="tag-filters">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Colour")}</span>
          <div class="grid grid-cols-2 gap-2">
            <label :for={c <- @colors} class="flex items-center gap-2 text-sm text-body">
              <input
                type="checkbox"
                name="color[]"
                value={c}
                checked={c in (@filters["colors"] || [])}
                class="h-4 w-4 rounded-xs border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {String.capitalize(c)}
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
      next_sort(socket.assigns.sort_by, socket.assigns.sort_order, sort_by(by, @sortable, :name))

    {:noreply, push_patch(socket, to: index_path(socket, %{"sort" => sort, "dir" => dir}))}
  end

  def handle_event("apply-filters", params, socket) do
    {:noreply,
     push_patch(socket,
       to: index_path(socket, %{"color" => params["color"] || [], "page" => nil})
     )}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/o/#{org(socket)}/tags?#{prune(%{"q" => socket.assigns.query})}")}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("validate_new", %{"tag" => params}, socket) do
    {:noreply, assign(socket, :new_form, Form.validate(socket.assigns.new_form, params))}
  end

  def handle_event("create", %{"tag" => params}, socket) do
    case Form.submit(socket.assigns.new_form, params: params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Tag added."))
         |> load_tags()
         |> assign_new_form()}

      {:error, form} ->
        {:noreply, assign(socket, :new_form, form)}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    tag = Enum.find(socket.assigns.tags, &(&1.id == id))

    form =
      Form.for_update(tag, :update,
        as: "tag",
        actor: socket.assigns.current_scope.user,
        tenant: socket.assigns.current_scope.organization
      )

    {:noreply, assign(socket, editing_id: id, edit_form: to_form(form))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_id: nil, edit_form: nil)}
  end

  def handle_event("validate_edit", %{"tag" => params}, socket) do
    {:noreply, assign(socket, :edit_form, Form.validate(socket.assigns.edit_form, params))}
  end

  def handle_event("update", %{"tag" => params}, socket) do
    case Form.submit(socket.assigns.edit_form, params: params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Tag updated."))
         |> assign(editing_id: nil, edit_form: nil)
         |> load_tags()}

      {:error, form} ->
        {:noreply, assign(socket, :edit_form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, tag} <- Tagging.get_tag(id, scope: scope),
         :ok <- Tagging.delete_tag(tag, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Tag deleted."))
       |> load_tags()}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not delete that tag."))}
    end
  end

  defp load_tags(socket) do
    page_data =
      Tagging.list_tags!(
        %{
          search_query: socket.assigns.query,
          filters: socket.assigns.filters,
          sort_by: socket.assigns.sort_by,
          sort_order: socket.assigns.sort_order
        },
        scope: socket.assigns.current_scope,
        page: [limit: @limit, offset: (socket.assigns.page - 1) * @limit, count: true]
      )

    assign(socket, tags: page_data.results, count: page_data.count || 0)
  end

  defp assign_new_form(socket) do
    form =
      Form.for_create(Tag, :create,
        as: "tag",
        actor: socket.assigns.current_scope.user,
        tenant: socket.assigns.current_scope.organization
      )

    assign(socket, :new_form, to_form(form))
  end

  defp index_path(socket, overrides) do
    params =
      %{
        "q" => socket.assigns.query,
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "color" => socket.assigns.filters["colors"] || []
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/tags?#{params}"
  end

  defp parse_filters(params) do
    valid = Enum.map(TagColor.values(), &to_string/1)

    %{"colors" => Enum.filter(List.wrap(params["color"]), &(&1 in valid))}
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  defp delete_confirm(%{usage_count: 0}), do: gettext("Delete this tag?")

  defp delete_confirm(%{usage_count: count}) do
    ngettext(
      "This tag is on 1 record. Deleting it removes it there too. Continue?",
      "This tag is on %{count} records. Deleting it removes it from them too. Continue?",
      count
    )
  end

  defp color_options do
    Enum.map(TagColor.values(), &{&1 |> to_string() |> String.capitalize(), &1})
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
