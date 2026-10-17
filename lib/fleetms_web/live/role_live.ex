defmodule FleetmsWeb.RoleLive do
  @moduledoc """
  Management UI for an organization's roles and their permissions. The
  organization (tenant) comes from `current_scope`, resolved from the `/o/:org_id`
  URL by the `:require_organization` on_mount hook.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Permissions
  alias Fleetms.Permissions.UI

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Roles & Permissions")
     |> assign(:role_form, to_form(%{"name" => "", "description" => ""}, as: :role))
     |> assign(:editing_role, nil)
     |> assign(:selected_perm_names, MapSet.new())
     |> assign(:grouped_permissions, UI.grouped_for_form())}
  end

  # Runs after the resolve_organization hook has assigned current_scope.
  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, load_roles(socket)}
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
      <.header>
        Roles &amp; Permissions
        <:subtitle>Manage roles and assign permissions for {@current_organization.name}.</:subtitle>
      </.header>

      <div class="mt-6 space-y-6">
        <section class="rounded-base border border-default bg-white dark:bg-gray-800 p-5 shadow-sm">
          <h2 class="mb-4 text-lg font-semibold text-heading">Create a role</h2>
          <.form for={@role_form} id="role-form" phx-submit="create_role">
            <div class="grid gap-x-4 sm:grid-cols-2">
              <.input field={@role_form[:name]} label="Name" placeholder="e.g. Dispatcher" />
              <.input
                field={@role_form[:description]}
                label="Description"
                placeholder="What this role is for"
              />
            </div>
            <.button variant="primary">Create role</.button>
          </.form>
        </section>

        <section class="space-y-3">
          <h2 class="text-lg font-semibold text-heading">Roles</h2>
          <.table id="roles" rows={@roles}>
            <:col :let={role} label="Name">{role.name}</:col>
            <:col :let={role} label="Description">{role.description}</:col>
            <:col :let={role} label="Type">
              <.badge color={if role.is_system, do: "brand", else: "gray"}>
                {if role.is_system, do: "System", else: "Custom"}
              </.badge>
            </:col>
            <:col :let={role} label="Permissions">{length(role.permissions)}</:col>
            <:action :let={role}>
              <.button size="xs" variant="secondary" phx-click="edit_role" phx-value-id={role.id}>
                {if role.is_system, do: "View permissions", else: "Edit permissions"}
              </.button>
            </:action>
            <:action :let={role}>
              <.button
                :if={not role.is_system}
                size="xs"
                variant="danger"
                phx-click="delete_role"
                phx-value-id={role.id}
                data-confirm="Delete this role?"
              >
                Delete
              </.button>
            </:action>
          </.table>
        </section>

        <section
          :if={@editing_role}
          class="rounded-base border border-default bg-white dark:bg-gray-800 p-5 shadow-sm"
        >
          <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
            <h2 class="text-lg font-semibold text-heading">
              Permissions for &ldquo;{@editing_role.name}&rdquo;
            </h2>
            <span :if={not @editing_role.is_system} class="text-sm text-body">
              {MapSet.size(@selected_perm_names)} selected
            </span>
          </div>

          <div
            :if={@editing_role.is_system}
            class="mb-4 flex items-start gap-2 rounded-base border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-900/20 dark:text-amber-200"
          >
            <.icon name="fa-lock" class="mt-0.5 shrink-0" />
            <span>
              This is a system role. Its permissions are managed automatically and kept in
              sync on each boot, so they can&rsquo;t be edited here. Create a custom role to
              assign your own set of permissions.
            </span>
          </div>

          <%!-- System roles: read-only view of the permissions they grant. --%>
          <div :if={@editing_role.is_system} class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <div :for={group <- @grouped_permissions} class="space-y-2">
              <p class="text-sm font-semibold text-heading">{group.group}</p>
              <ul class="space-y-1">
                <li
                  :for={perm <- group.permissions}
                  :if={MapSet.member?(@selected_perm_names, perm.name)}
                  class="flex items-center gap-2 text-sm text-body"
                >
                  <.icon name="fa-check" class="text-xs text-green-600" />
                  <span title={perm.description}>{perm.label}</span>
                </li>
              </ul>
            </div>
          </div>

          <%!-- Custom roles: an editable grid with per-group select-all / clear. --%>
          <.form
            :if={not @editing_role.is_system}
            for={%{}}
            phx-change="perms_changed"
            phx-submit="save_permissions"
          >
            <input type="hidden" name="role_id" value={@editing_role.id} />

            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <fieldset :for={group <- @grouped_permissions} class="space-y-2">
                <div class="flex items-center justify-between">
                  <legend class="text-sm font-semibold text-heading">{group.group}</legend>
                  <div class="flex gap-2 text-xs">
                    <button
                      type="button"
                      phx-click="select_group"
                      phx-value-group={group.group}
                      class="font-medium text-brand hover:underline"
                    >
                      All
                    </button>
                    <span class="text-body">·</span>
                    <button
                      type="button"
                      phx-click="clear_group"
                      phx-value-group={group.group}
                      class="font-medium text-body hover:underline"
                    >
                      None
                    </button>
                  </div>
                </div>
                <label
                  :for={perm <- group.permissions}
                  class="flex items-center gap-2 text-sm text-body"
                >
                  <input
                    type="checkbox"
                    name="permissions[]"
                    value={perm.name}
                    checked={MapSet.member?(@selected_perm_names, perm.name)}
                    class="h-4 w-4 rounded-xs border border-default-medium bg-neutral-secondary-medium text-brand focus:ring-2 focus:ring-brand-soft"
                  />
                  <span title={perm.description}>{perm.label}</span>
                </label>
              </fieldset>
            </div>

            <div class="mt-6 flex gap-2 border-t border-default pt-4">
              <.button variant="primary">Save permissions</.button>
              <.button type="button" variant="secondary" phx-click="cancel_edit">Cancel</.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("create_role", %{"role" => params}, socket) do
    %{organization: org, user: user} = socket.assigns.current_scope

    case Permissions.create_role(params, org, user) do
      {:ok, _role} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role created.")
         |> assign(:role_form, to_form(%{"name" => "", "description" => ""}, as: :role))
         |> load_roles()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not create role: #{inspect_error(error)}")}
    end
  end

  def handle_event("edit_role", %{"id" => id}, socket) do
    role = Enum.find(socket.assigns.roles, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:editing_role, role)
     |> assign(:selected_perm_names, UI.role_permission_names(role))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_role: nil, selected_perm_names: MapSet.new())}
  end

  def handle_event("perms_changed", params, socket) do
    names = params |> Map.get("permissions", []) |> MapSet.new()
    {:noreply, assign(socket, :selected_perm_names, names)}
  end

  def handle_event("select_group", %{"group" => group}, socket) do
    selected = MapSet.union(socket.assigns.selected_perm_names, group_perm_names(socket, group))
    {:noreply, assign(socket, :selected_perm_names, selected)}
  end

  def handle_event("clear_group", %{"group" => group}, socket) do
    selected =
      MapSet.difference(socket.assigns.selected_perm_names, group_perm_names(socket, group))

    {:noreply, assign(socket, :selected_perm_names, selected)}
  end

  def handle_event("save_permissions", %{"role_id" => role_id}, socket) do
    %{organization: org, user: user} = socket.assigns.current_scope
    role = Enum.find(socket.assigns.roles, &(&1.id == role_id))
    names = MapSet.to_list(socket.assigns.selected_perm_names)
    permission_ids = UI.resolve_db_ids(names)

    case Permissions.set_role_permissions(role, permission_ids, org, user) do
      {:ok, _role} ->
        {:noreply,
         socket
         |> put_flash(:info, "Permissions updated.")
         |> assign(editing_role: nil, selected_perm_names: MapSet.new())
         |> load_roles()}

      {:error, error} ->
        {:noreply,
         put_flash(socket, :error, "Could not save permissions: #{inspect_error(error)}")}
    end
  end

  def handle_event("delete_role", %{"id" => id}, socket) do
    %{organization: org, user: user} = socket.assigns.current_scope
    role = Enum.find(socket.assigns.roles, &(&1.id == id))

    case Fleetms.Accounts.delete_role(role, tenant: org, actor: user) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Role deleted.") |> load_roles()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not delete role: #{inspect_error(error)}")}
    end
  end

  # The permission names belonging to a group, for the select-all / clear buttons.
  defp group_perm_names(socket, group) do
    socket.assigns.grouped_permissions
    |> Enum.find(%{permissions: []}, &(&1.group == group))
    |> Map.fetch!(:permissions)
    |> MapSet.new(& &1.name)
  end

  defp load_roles(socket) do
    %{organization: org, user: user} = socket.assigns.current_scope
    assign(socket, :roles, Permissions.list_roles(org, user))
  end

  defp inspect_error(%{errors: [error | _]}), do: Exception.message(error)
  defp inspect_error(error) when is_exception(error), do: Exception.message(error)
  defp inspect_error(error), do: inspect(error)
end
