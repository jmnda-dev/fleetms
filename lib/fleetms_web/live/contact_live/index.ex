defmodule FleetmsWeb.ContactLive.Index do
  @moduledoc """
  Lists the organization's contacts (the address book of external parties) with
  free-text search, a type filter, sortable columns and pagination. Rows open the
  contact for editing; entries can be archived and restored. All list state lives in
  the URL query string.
  """
  use FleetmsWeb, :live_view

  import FleetmsWeb.ListView

  alias Fleetms.Contacts
  alias Fleetms.Contacts.ContactType
  alias Fleetms.Scope

  @limit 20
  @sortable ~w(name company contact_type inserted_at)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Contacts"), active_link: :contacts)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    query = params["q"] || ""
    type = parse_type(params["type"])
    archived? = params["archived"] == "1"
    sort_by = sort_by(params["sort"], @sortable, :name)
    sort_order = sort_order(params["dir"] || "asc")
    page = page_number(params["page"])

    opts = [scope: scope, page: [limit: @limit, offset: (page - 1) * @limit, count: true]]

    result =
      if archived? do
        Contacts.list_archived_contacts(
          %{search_query: query, sort_by: sort_by, sort_order: sort_order},
          opts
        )
      else
        Contacts.list_contacts(
          %{search_query: query, contact_type: type, sort_by: sort_by, sort_order: sort_order},
          opts
        )
      end

    socket =
      case result do
        {:ok, data} ->
          assign(socket,
            contacts: data.results,
            count: data.count || 0,
            page: page,
            limit: @limit,
            query: query,
            type: type,
            sort_by: sort_by,
            sort_order: sort_order,
            filter_count: if(type, do: 1, else: 0),
            archived_view: archived?,
            type_options: type_options(),
            can_create: Scope.has_permission?(scope, :create_contact),
            can_update: Scope.has_permission?(scope, :update_contact),
            can_delete: Scope.has_permission?(scope, :delete_contact)
          )

        {:error, %Ash.Error.Forbidden{}} ->
          socket
          |> put_flash(:error, gettext("You don't have access to contacts here."))
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
        %{label: gettext("Contacts")}
      ]} />

      <.header>
        {if @archived_view, do: gettext("Archived contacts"), else: gettext("Contacts")}
        <:subtitle>
          {if @archived_view,
            do: gettext("%{count} archived", count: @count),
            else: gettext("%{count} in the address book", count: @count)}
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
            navigate={~p"/o/#{org(assigns)}/contacts/new"}
          >
            <.icon name="fa-plus" class="me-2" /> {gettext("New contact")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <.list_toolbar
          :if={not @archived_view}
          query={@query}
          filter_count={@filter_count}
          drawer_id="contact-filters"
          placeholder={gettext("Search name, company, email…")}
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
                placeholder={gettext("Search name, company, email…")}
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
                  label={gettext("Name")}
                  field="name"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <.sort_th
                  label={gettext("Type")}
                  field="contact_type"
                  sort_by={@sort_by}
                  sort_order={@sort_order}
                />
                <th class="px-4 py-3 font-semibold">{gettext("Contact")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={contact <- @contacts}
                class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <th
                  scope="row"
                  phx-click={row_navigate(assigns, contact)}
                  class="cursor-pointer whitespace-nowrap px-4 py-3 font-medium text-heading"
                >
                  {contact.name}
                  <span
                    :if={contact.company || contact.title}
                    class="block text-xs font-normal text-body"
                  >
                    {[contact.title, contact.company] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")}
                  </span>
                </th>
                <td phx-click={row_navigate(assigns, contact)} class="cursor-pointer px-4 py-3">
                  <.badge color="gray">{humanize(contact.contact_type)}</.badge>
                </td>
                <td phx-click={row_navigate(assigns, contact)} class="cursor-pointer px-4 py-3">
                  <span class="block">{contact.phone}</span>
                  <span class="block text-xs text-body">{contact.email}</span>
                </td>
                <td class="px-4 py-3">
                  <div class="flex items-center justify-end gap-1">
                    <.button
                      :if={@archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      phx-click="restore"
                      phx-value-id={contact.id}
                    >
                      <.icon name="fa-rotate-left" class="me-1 text-xs" /> {gettext("Restore")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_update}
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/contacts/#{contact.id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={not @archived_view and @can_delete}
                      size="xs"
                      variant="danger"
                      phx-click="archive"
                      phx-value-id={contact.id}
                      data-confirm={gettext("Archive this contact? You can restore it later.")}
                    >
                      {gettext("Archive")}
                    </.button>
                  </div>
                </td>
              </tr>
              <tr :if={@contacts == []}>
                <td colspan="4" class="px-4 py-6">
                  <.empty_state
                    icon="fa-address-book"
                    title={
                      if @archived_view,
                        do: gettext("No archived contacts"),
                        else: gettext("No contacts found")
                    }
                    message={
                      unless @archived_view,
                        do:
                          gettext(
                            "Keep the vendors, insurers and inspectors you deal with in one place."
                          )
                    }
                  >
                    <.button
                      :if={@can_create and not @archived_view}
                      navigate={~p"/o/#{org(assigns)}/contacts/new"}
                      size="sm"
                    >
                      <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("New contact")}
                    </.button>
                  </.empty_state>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <.list_pagination count={@count} page={@page} limit={@limit} />
      </div>

      <.filter_drawer :if={not @archived_view} id="contact-filters">
        <div>
          <span class="mb-2 block text-sm font-medium text-heading">{gettext("Type")}</span>
          <div class="space-y-2">
            <label class="flex items-center gap-2 text-sm text-body">
              <input
                type="radio"
                name="type"
                value=""
                checked={is_nil(@type)}
                class="h-4 w-4 border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {gettext("All types")}
            </label>
            <label
              :for={{label, value} <- @type_options}
              class="flex items-center gap-2 text-sm text-body"
            >
              <input
                type="radio"
                name="type"
                value={value}
                checked={to_string(@type) == value}
                class="h-4 w-4 border-default-medium bg-neutral-secondary-medium text-brand focus:ring-brand-soft"
              />
              {label}
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
       to: index_path(socket, %{"type" => nilify(params["type"]), "page" => nil})
     )}
  end

  def handle_event("clear-filters", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/o/#{org(socket)}/contacts?#{prune(%{"q" => socket.assigns.query})}"
     )}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: index_path(socket, %{"page" => page}))}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with {:ok, contact} <- Contacts.get_contact(id, scope: scope),
         :ok <- Contacts.delete_contact(contact, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Contact archived."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not archive that contact."))}
    end
  end

  def handle_event("restore", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    with contact when not is_nil(contact) <- Enum.find(socket.assigns.contacts, &(&1.id == id)),
         {:ok, _} <- Contacts.restore_contact(contact, %{}, scope: scope) do
      {:noreply,
       socket
       |> put_flash(:info, gettext("Contact restored."))
       |> push_patch(to: index_path(socket, %{}))}
    else
      _ -> {:noreply, put_flash(socket, :error, gettext("Could not restore that contact."))}
    end
  end

  # --- URL <-> state ---

  defp index_path(socket, overrides) do
    params =
      %{
        "q" => socket.assigns.query,
        "archived" => if(socket.assigns.archived_view, do: "1"),
        "sort" => to_string(socket.assigns.sort_by),
        "dir" => to_string(socket.assigns.sort_order),
        "page" => to_string(socket.assigns.page),
        "type" => socket.assigns.type && to_string(socket.assigns.type)
      }
      |> Map.merge(overrides)
      |> prune()

    ~p"/o/#{org(socket)}/contacts?#{params}"
  end

  defp toggle_archived_path(assigns) do
    if assigns.archived_view do
      ~p"/o/#{org(assigns)}/contacts"
    else
      ~p"/o/#{org(assigns)}/contacts?#{%{"archived" => "1"}}"
    end
  end

  defp row_navigate(%{archived_view: true}, _contact), do: nil

  defp row_navigate(assigns, contact),
    do: JS.navigate(~p"/o/#{org(assigns)}/contacts/#{contact.id}/edit")

  defp type_options do
    Enum.map(ContactType.values(), &{humanize(&1), to_string(&1)})
  end

  defp parse_type(value) when value in [nil, ""], do: nil

  defp parse_type(value) do
    if to_string(value) in Enum.map(ContactType.values(), &to_string/1), do: value, else: nil
  end

  defp humanize(value), do: value |> to_string() |> String.capitalize()

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
