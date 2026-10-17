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
                Edit permissions
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
          <h2 class="mb-4 text-lg font-semibold text-heading">
            Permissions for &ldquo;{@editing_role.name}&rdquo;
          </h2>
          <.form for={%{}} phx-submit="save_permissions">
            <input type="hidden" name="role_id" value={@editing_role.id} />

            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <fieldset :for={group <- @grouped_permissions} class="space-y-2">
                <legend class="mb-1 text-sm font-semibold text-heading">{group.group}</legend>
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

  def handle_event("save_permissions", %{"role_id" => role_id} = params, socket) do
    %{organization: org, user: user} = socket.assigns.current_scope
    role = Enum.find(socket.assigns.roles, &(&1.id == role_id))
    names = Map.get(params, "permissions", [])
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

  defp load_roles(socket) do
    %{organization: org, user: user} = socket.assigns.current_scope
    assign(socket, :roles, Permissions.list_roles(org, user))
  end

  defp inspect_error(%{errors: [error | _]}), do: Exception.message(error)
  defp inspect_error(error) when is_exception(error), do: Exception.message(error)
  defp inspect_error(error), do: inspect(error)
end
