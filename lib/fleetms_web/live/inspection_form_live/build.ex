defmodule FleetmsWeb.InspectionFormLive.Build do
  @moduledoc """
  The inspection form builder page.

  The form's `draft_schema` is handed to a client-owned Svelte island (mounted by
  the `InspectionBuilder` hook) as JSON. The island edits the document entirely on
  the client and pushes the whole document back via the "save_schema" event, which
  persists it to `draft_schema`. Publishing is a separate server-side action that
  freezes the persisted draft into a new immutable version.

  The island container uses `phx-update="ignore"` so LiveView never patches the
  Svelte-owned DOM; only regions outside it (the version list, flashes) re-render.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts
  alias Fleetms.Inspections
  alias Fleetms.Scope

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :inspections)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope

    case Inspections.get_inspection_form(id, scope: scope) do
      {:ok, form} ->
        {:noreply,
         socket
         |> assign(
           page_title: form.title,
           form: form,
           schema_json: encode_schema(form.draft_schema),
           users_json: encode_members(scope),
           roles_json: encode_roles(scope),
           can_update: Scope.has_permission?(scope, :update_inspection_form),
           can_publish: Scope.has_permission?(scope, :publish_inspection_form)
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("That inspection form could not be found."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/inspection-forms")}
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
        %{label: gettext("Inspection Forms"), path: ~p"/o/#{org(assigns)}/inspection-forms"},
        %{label: @page_title}
      ]} />

      <.header>
        {@form.title}
        <:subtitle>
          {gettext("Build the form, then publish it to make a new version available.")}
        </:subtitle>
        <:actions>
          <.button
            :if={@can_publish}
            variant="primary"
            phx-click="publish"
            data-confirm={gettext("Publish the current draft as a new version?")}
          >
            <.icon name="fa-circle-up" class="me-2" /> {gettext("Publish")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 grid gap-6 lg:grid-cols-[1fr_260px]">
        <div class="rounded-base border border-default bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-900">
          <div
            id={"inspection-builder-#{@form.id}"}
            phx-hook="InspectionBuilder"
            phx-update="ignore"
            data-schema={@schema_json}
            data-users={@users_json}
            data-roles={@roles_json}
          >
          </div>
        </div>

        <aside class="space-y-4">
          <div class="rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800">
            <h3 class="mb-2 text-sm font-semibold text-heading">{gettext("Published versions")}</h3>
            <ul :if={@form.versions != []} class="space-y-1 text-sm text-body">
              <li :for={version <- @form.versions} class="flex justify-between">
                <span>{gettext("v%{n}", n: version.version_number)}</span>
                <span class="text-gray-500 dark:text-gray-400">
                  {Calendar.strftime(version.published_at, "%Y-%m-%d")}
                </span>
              </li>
            </ul>
            <p :if={@form.versions == []} class="text-sm text-gray-500 dark:text-gray-400">
              {gettext("Not published yet.")}
            </p>
          </div>
        </aside>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("save_schema", %{"schema" => schema}, socket) do
    scope = socket.assigns.current_scope

    case Inspections.update_inspection_form(socket.assigns.form, %{draft_schema: schema},
           scope: scope
         ) do
      {:ok, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:info, gettext("Draft saved."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save the draft."))}
    end
  end

  def handle_event("publish", _params, socket) do
    scope = socket.assigns.current_scope

    case Inspections.publish_inspection_form(socket.assigns.form, scope: scope) do
      {:ok, _form} ->
        # Reload to pick up the new version and status.
        form = Inspections.get_inspection_form!(socket.assigns.form.id, scope: scope)

        {:noreply,
         socket
         |> assign(form: form, page_title: form.title)
         |> put_flash(:info, gettext("Published version %{n}.", n: form.latest_version_number))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not publish the form."))}
    end
  end

  defp encode_schema(schema) do
    {:ok, dumped} = Ash.Type.dump_to_embedded(Inspections.Schema, schema, [])
    Jason.encode!(dumped)
  end

  # The org's active members, as `[%{id:, name:}]`, for the workflow builder's
  # assignee/recipient pickers.
  defp encode_members(scope) do
    Accounts.list_user_organizations!(
      scope: scope,
      query: [filter: [organization_id: scope.organization.id, status: :active]],
      load: [user: [:email, profile: [:first_name, :last_name]]]
    )
    |> Enum.map(fn membership ->
      %{id: membership.user_id, name: member_name(membership.user)}
    end)
    |> Jason.encode!()
  end

  # The org's roles, as `[%{id:, name:}]`, for the workflow builder's role picker.
  defp encode_roles(scope) do
    Accounts.list_roles!(scope: scope)
    |> Enum.map(&%{id: &1.id, name: &1.name})
    |> Jason.encode!()
  end

  defp member_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp member_name(%{email: email}), do: to_string(email)

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
