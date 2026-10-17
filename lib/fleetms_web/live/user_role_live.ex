defmodule FleetmsWeb.UserRoleLive do
  @moduledoc """
  Management UI for assigning roles to the users of an organization and revoking
  those assignments. The organization (tenant) comes from `current_scope`,
  resolved from the `/o/:org_id` URL by the `:require_organization` on_mount hook.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Permissions

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "User Roles")}
  end

  # Runs after the resolve_organization hook has assigned current_scope.
  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, load_data(socket)}
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
        User Roles
        <:subtitle>Assign roles to the people in {@current_organization.name}.</:subtitle>
      </.header>

      <div class="mt-6 space-y-4">
        <div
          :for={member <- @members}
          class="rounded-base border border-default bg-white dark:bg-gray-800 p-4 shadow-sm"
        >
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="space-y-2">
              <h3 class="font-semibold text-heading">{member.email || member.username}</h3>
              <ul class="flex flex-wrap gap-2">
                <li
                  :for={ur <- assignments_for(@user_roles, member.id)}
                  class="inline-flex items-center gap-1.5 rounded bg-neutral-secondary-medium px-2 py-1 text-sm text-body"
                >
                  <span>{ur.role.name}</span>
                  <button
                    type="button"
                    phx-click="revoke"
                    phx-value-id={ur.id}
                    data-confirm="Revoke this role?"
                    class="text-body hover:text-danger"
                    aria-label={"Revoke #{ur.role.name}"}
                  >
                    <.icon name="fa-xmark" class="text-xs" />
                  </button>
                </li>
                <li
                  :if={assignments_for(@user_roles, member.id) == []}
                  class="text-sm text-body"
                >
                  No roles assigned
                </li>
              </ul>
            </div>

            <.form
              for={%{}}
              id={"assign-form-#{member.id}"}
              phx-submit="assign"
              class="flex items-center gap-2"
            >
              <input type="hidden" name="user_id" value={member.id} />
              <select
                name="role_id"
                class="block rounded-base border border-default-medium bg-neutral-secondary-medium px-3 py-2 text-sm text-body focus:border-brand focus:ring-brand"
              >
                <option value="">Choose a role…</option>
                <option :for={role <- @roles} value={role.id}>{role.name}</option>
              </select>
              <.button size="sm" variant="primary">Assign</.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("assign", %{"user_id" => user_id, "role_id" => role_id}, socket)
      when role_id != "" do
    %{organization: org, user: actor} = socket.assigns.current_scope

    case Permissions.assign_role(user_id, role_id, org, actor) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Role assigned.") |> load_data()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not assign role: #{inspect_error(error)}")}
    end
  end

  def handle_event("assign", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please choose a role.")}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    %{organization: org, user: actor} = socket.assigns.current_scope
    user_role = Enum.find(socket.assigns.user_roles, &(&1.id == id))

    case Permissions.revoke_role(user_role, org, actor) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Role revoked.") |> load_data()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not revoke role: #{inspect_error(error)}")}
    end
  end

  defp load_data(socket) do
    %{organization: org, user: user} = socket.assigns.current_scope
    org = Fleetms.Accounts.get_organization!(org.id, actor: user, load: [:users])
    roles = Permissions.list_roles(org, user)

    user_roles =
      Fleetms.Accounts.list_user_roles!(tenant: org, actor: user, load: [:role, :user])

    assign(socket, members: org.users, roles: roles, user_roles: user_roles)
  end

  defp assignments_for(user_roles, user_id) do
    Enum.filter(user_roles, &(&1.user_id == user_id))
  end

  defp inspect_error(%{errors: [error | _]}), do: Exception.message(error)
  defp inspect_error(error) when is_exception(error), do: Exception.message(error)
  defp inspect_error(error), do: inspect(error)
end
