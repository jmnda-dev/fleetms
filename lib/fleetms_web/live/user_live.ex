defmodule FleetmsWeb.UserLive do
  @moduledoc """
  Member management for an organization: list members, add them (invite by email
  or provision a username-only account), view details, suspend/reactivate, and
  remove. All mutations go through `Fleetms.Membership`, which enforces the
  `manage_users` permission. Create/view/delete are URL-aware modals.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Membership
  alias Fleetms.Permissions

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Users"))}
  end

  # Runs after the resolve_organization hook has assigned current_scope.
  @impl true
  def handle_params(params, _uri, socket) do
    case load_members(socket) do
      {:ok, socket} -> {:noreply, apply_action(socket, socket.assigns.live_action, params)}
      {:error, socket} -> {:noreply, socket}
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:member_mode, :invite)
    |> assign(:member_form, to_form(%{}, as: "member"))
  end

  defp apply_action(socket, :edit, %{"user_id" => user_id}) do
    with_selected_member(socket, user_id, fn socket, membership ->
      user_roles = member_user_roles(socket.assigns.current_scope, user_id)
      current_ids = Enum.map(user_roles, & &1.role_id)

      socket
      |> assign(:selected_member, membership)
      |> assign(:member_user_roles, user_roles)
      |> assign(:edit_form, to_form(%{"role_ids" => current_ids}, as: "edit"))
    end)
  end

  defp apply_action(socket, action, %{"user_id" => user_id}) when action in [:show, :delete] do
    with_selected_member(socket, user_id, fn socket, membership ->
      assign(socket, :selected_member, membership)
    end)
  end

  defp apply_action(socket, _action, _params), do: socket

  defp with_selected_member(socket, user_id, fun) do
    case Enum.find(socket.assigns.members, &(&1.user_id == user_id)) do
      nil ->
        socket
        |> put_flash(:error, gettext("That member could not be found."))
        |> push_patch(to: ~p"/o/#{org(socket)}/users")

      membership ->
        fun.(socket, membership)
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
        %{label: gettext("Users")}
      ]} />

      <.header>
        {gettext("Users")}
        <:subtitle>
          {gettext("People who belong to %{org}.", org: @current_organization.name)}
        </:subtitle>
        <:actions>
          <.button :if={@can_manage} navigate={~p"/o/#{org(assigns)}/users/new"}>
            <.icon name="fa-user-plus" class="me-2" /> {gettext("Add member")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 overflow-hidden rounded-base border border-default bg-white dark:bg-gray-800 shadow-sm">
        <table class="w-full text-left text-sm text-body">
          <thead class="bg-gray-50 dark:bg-gray-700 text-xs uppercase text-heading">
            <tr>
              <th scope="col" class="px-4 py-3 font-semibold">{gettext("Member")}</th>
              <th scope="col" class="px-4 py-3 font-semibold">{gettext("Identifier")}</th>
              <th scope="col" class="px-4 py-3 font-semibold">{gettext("Roles")}</th>
              <th scope="col" class="px-4 py-3 font-semibold">{gettext("Status")}</th>
              <th scope="col" class="px-4 py-3 text-right font-semibold">{gettext("Actions")}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={member <- @members}
              class="border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              <td class="whitespace-nowrap px-4 py-3">
                <div class="flex items-center gap-3">
                  <span class="flex h-9 w-9 items-center justify-center rounded-full bg-brand-softer text-sm font-semibold text-fg-brand-strong">
                    {initials(member)}
                  </span>
                  <span class="font-medium text-heading">{member_name(member)}</span>
                </div>
              </td>
              <td class="px-4 py-3">{identifier(member)}</td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap gap-1">
                  <.badge :for={role <- roles_for(@roles_by_user, member)} color="gray">
                    {role}
                  </.badge>
                  <span :if={roles_for(@roles_by_user, member) == []} class="text-body">—</span>
                </div>
              </td>
              <td class="px-4 py-3">
                <.badge :if={member.owner?} color="brand">{gettext("Owner")}</.badge>
                <.badge :if={!member.owner? and member.status == :active} color="success">
                  {gettext("Active")}
                </.badge>
                <.badge :if={member.status == :suspended} color="warning">
                  {gettext("Suspended")}
                </.badge>
              </td>
              <td class="px-4 py-3">
                <div class="flex items-center justify-end gap-1">
                  <.button
                    size="xs"
                    variant="ghost"
                    navigate={~p"/o/#{org(assigns)}/users/#{member.user_id}"}
                  >
                    {gettext("View")}
                  </.button>
                  <%= if @can_manage and not member.owner? do %>
                    <.button
                      size="xs"
                      variant="secondary"
                      navigate={~p"/o/#{org(assigns)}/users/#{member.user_id}/edit"}
                    >
                      {gettext("Edit")}
                    </.button>
                    <.button
                      :if={member.status == :active}
                      size="xs"
                      variant="secondary"
                      phx-click="suspend"
                      phx-value-id={member.id}
                    >
                      {gettext("Suspend")}
                    </.button>
                    <.button
                      :if={member.status == :suspended}
                      size="xs"
                      variant="secondary"
                      phx-click="reactivate"
                      phx-value-id={member.id}
                    >
                      {gettext("Reactivate")}
                    </.button>
                    <.button
                      size="xs"
                      variant="danger"
                      navigate={~p"/o/#{org(assigns)}/users/#{member.user_id}/delete"}
                    >
                      {gettext("Remove")}
                    </.button>
                  <% end %>
                </div>
              </td>
            </tr>
            <tr :if={@members == []}>
              <td colspan="5" class="px-4 py-8 text-center text-body">
                {gettext("No members yet.")}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.live_modal
        :if={@live_action == :new}
        id="member-modal"
        show
        on_cancel={JS.patch(~p"/o/#{org(assigns)}/users")}
      >
        <:title>{gettext("Add member")}</:title>

        <div class="mb-4 flex gap-2 rounded-base bg-neutral-secondary-soft p-1">
          <button
            type="button"
            phx-click="set-mode"
            phx-value-mode="invite"
            class={mode_tab(@member_mode == :invite)}
          >
            {gettext("Invite by email")}
          </button>
          <button
            type="button"
            phx-click="set-mode"
            phx-value-mode="username"
            class={mode_tab(@member_mode == :username)}
          >
            {gettext("Create with username")}
          </button>
        </div>

        <.form
          :let={f}
          for={@member_form}
          phx-submit="create-member"
          id="member-form"
          class="space-y-4"
        >
          <%= if @member_mode == :invite do %>
            <p class="text-sm text-body">
              {gettext("We'll email them a link to set up their account and join.")}
            </p>
            <.input field={f[:email]} type="email" label={gettext("Email")} required />
          <% else %>
            <p class="text-sm text-body">
              {gettext(
                "For people without an email. They sign in with the username and password you set."
              )}
            </p>
            <div class="grid grid-cols-2 gap-3">
              <.input field={f[:first_name]} label={gettext("First name")} required />
              <.input field={f[:last_name]} label={gettext("Last name")} />
            </div>
            <.input field={f[:username]} label={gettext("Username")} required />
            <.input field={f[:password]} type="password" label={gettext("Password")} required />
            <.input
              field={f[:password_confirmation]}
              type="password"
              label={gettext("Confirm password")}
              required
            />
          <% end %>

          <.input
            field={f[:role_id]}
            type="select"
            label={gettext("Role")}
            prompt={gettext("No role")}
            options={Enum.map(@available_roles, &{&1.name, &1.id})}
          />
        </.form>

        <:footer>
          <.button type="submit" form="member-form">
            <%= if @member_mode == :invite do %>
              {gettext("Send invitation")}
            <% else %>
              {gettext("Create member")}
            <% end %>
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/users"}>
            {gettext("Cancel")}
          </.button>
        </:footer>
      </.live_modal>

      <.live_modal
        :if={@live_action == :show}
        id="member-view-modal"
        show
        on_cancel={JS.patch(~p"/o/#{org(assigns)}/users")}
      >
        <:title>{member_name(@selected_member)}</:title>
        <.list>
          <:item title={gettext("Name")}>{member_name(@selected_member)}</:item>
          <:item title={gettext("Identifier")}>{identifier(@selected_member)}</:item>
          <:item title={gettext("Roles")}>
            {roles_for(@roles_by_user, @selected_member) |> Enum.join(", ") |> blank_dash()}
          </:item>
          <:item title={gettext("Status")}>
            {if @selected_member.owner?,
              do: gettext("Owner"),
              else: status_label(@selected_member.status)}
          </:item>
        </.list>
        <:footer>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/users"}>
            {gettext("Close")}
          </.button>
        </:footer>
      </.live_modal>

      <.live_modal
        :if={@live_action == :edit}
        id="member-edit-modal"
        show
        on_cancel={JS.patch(~p"/o/#{org(assigns)}/users")}
      >
        <:title>{gettext("Edit %{name}", name: member_name(@selected_member))}</:title>
        <.form :let={f} for={@edit_form} id="member-edit-form" phx-submit="update-member">
          <p :if={@available_roles == []} class="text-sm text-body">
            {gettext("No roles defined yet. Create some under Roles & Permissions.")}
          </p>
          <.search_select
            :if={@available_roles != []}
            field={f[:role_ids]}
            multiple
            label={gettext("Roles")}
            prompt={gettext("Search and select roles…")}
            options={Enum.map(@available_roles, &{&1.name, &1.id})}
          />
        </.form>
        <:footer>
          <.button type="submit" form="member-edit-form">{gettext("Save changes")}</.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/users"}>
            {gettext("Cancel")}
          </.button>
        </:footer>
      </.live_modal>

      <.live_modal
        :if={@live_action == :delete}
        id="member-delete-modal"
        size="md"
        show
        on_cancel={JS.patch(~p"/o/#{org(assigns)}/users")}
      >
        <:title>{gettext("Remove member")}</:title>
        <p>
          {gettext("Remove %{name} from %{org}? Their account is kept, but they lose access here.",
            name: member_name(@selected_member),
            org: @current_organization.name
          )}
        </p>
        <:footer>
          <.button variant="danger" phx-click="remove" phx-value-id={@selected_member.id}>
            {gettext("Remove member")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/users"}>
            {gettext("Cancel")}
          </.button>
        </:footer>
      </.live_modal>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("set-mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :member_mode, String.to_existing_atom(mode))}
  end

  def handle_event("create-member", %{"member" => params}, socket) do
    scope = socket.assigns.current_scope
    role_id = blank_to_nil(params["role_id"])

    result =
      case socket.assigns.member_mode do
        :invite ->
          Membership.invite_member(
            %{email: params["email"], role_id: role_id},
            scope.organization,
            scope.user
          )

        :username ->
          Membership.create_member_with_username(
            %{
              username: params["username"],
              password: params["password"],
              password_confirmation: params["password_confirmation"],
              profile: %{
                first_name: params["first_name"],
                last_name: blank_to_nil(params["last_name"])
              },
              role_id: role_id
            },
            scope.organization,
            scope.user
          )
      end

    case result do
      {:ok, :invited, _} -> {:noreply, done(socket, gettext("Invitation sent."))}
      {:ok, :added, _} -> {:noreply, done(socket, gettext("Member added."))}
      {:ok, _user} -> {:noreply, done(socket, gettext("Member created."))}
      {:error, reason} -> {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  def handle_event("update-member", %{"edit" => params}, socket) do
    scope = socket.assigns.current_scope
    desired = Map.get(params, "role_ids", [])
    current = Enum.map(socket.assigns.member_user_roles, & &1.role_id)
    member = socket.assigns.selected_member

    Enum.each(desired -- current, fn role_id ->
      Permissions.assign_role(member.user_id, role_id, scope.organization, scope.user)
    end)

    Enum.each(current -- desired, fn role_id ->
      user_role = Enum.find(socket.assigns.member_user_roles, &(&1.role_id == role_id))
      Permissions.revoke_role(user_role, scope.organization, scope.user)
    end)

    {:noreply, done(socket, gettext("Roles updated."))}
  end

  def handle_event("suspend", %{"id" => id}, socket) do
    with_membership(socket, id, &Membership.suspend_member/3, gettext("Member suspended."))
  end

  def handle_event("reactivate", %{"id" => id}, socket) do
    with_membership(socket, id, &Membership.reactivate_member/3, gettext("Member reactivated."))
  end

  def handle_event("remove", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.members, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      membership ->
        case Membership.remove_member(membership, scope.organization, scope.user) do
          {:ok, _} -> {:noreply, done(socket, gettext("Member removed."))}
          {:error, reason} -> {:noreply, put_flash(socket, :error, error_message(reason))}
        end
    end
  end

  defp with_membership(socket, id, fun, success_message) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.members, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      membership ->
        case fun.(membership, scope.organization, scope.user) do
          {:ok, _} ->
            {:ok, socket} = load_members(socket)
            {:noreply, put_flash(socket, :info, success_message)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, error_message(reason))}
        end
    end
  end

  # --- data loading ---

  defp load_members(socket) do
    scope = socket.assigns.current_scope

    case Membership.list_members(scope.organization, scope.user) do
      {:ok, members} ->
        socket =
          socket
          |> assign(:members, members)
          |> assign(:roles_by_user, roles_by_user(scope))
          |> assign(:available_roles, Permissions.list_roles(scope.organization, scope.user))
          |> assign(:can_manage, Fleetms.Scope.has_permission?(scope, :manage_users))

        {:ok, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, gettext("You don't have access to manage users here."))
          |> push_navigate(to: ~p"/o/#{org(socket)}")

        {:error, socket}
    end
  end

  defp roles_by_user(scope) do
    Fleetms.Accounts.list_user_roles!(
      tenant: scope.organization,
      actor: scope.user,
      load: [:role]
    )
    |> Enum.group_by(& &1.user_id, & &1.role.name)
  end

  defp member_user_roles(scope, user_id) do
    Fleetms.Accounts.list_user_roles!(tenant: scope.organization, actor: scope.user)
    |> Enum.filter(&(&1.user_id == user_id))
  end

  # --- display helpers ---

  defp member_name(membership) do
    case membership.user.profile do
      %{first_name: first} = profile when is_binary(first) ->
        [first, profile.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

      _ ->
        identifier(membership)
    end
  end

  defp identifier(membership) do
    user = membership.user
    to_string(user.email || user.username)
  end

  defp initials(membership) do
    membership
    |> member_name()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
    |> case do
      "" -> "?"
      letters -> letters
    end
  end

  defp roles_for(roles_by_user, membership), do: Map.get(roles_by_user, membership.user_id, [])

  defp status_label(:active), do: gettext("Active")
  defp status_label(:suspended), do: gettext("Suspended")

  defp mode_tab(active?) do
    [
      "flex-1 rounded px-3 py-1.5 text-sm font-medium",
      if(active?,
        do: "bg-white dark:bg-gray-800 text-heading shadow-xs",
        else: "text-body hover:text-heading"
      )
    ]
  end

  defp done(socket, message) do
    {:ok, socket} = load_members(socket)

    socket
    |> put_flash(:info, message)
    |> push_patch(to: ~p"/o/#{org(socket)}/users")
  end

  defp blank_dash(""), do: "—"
  defp blank_dash(value), do: value

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp error_message(:forbidden), do: gettext("You're not allowed to do that.")
  defp error_message({:cannot, what}), do: gettext("You can't %{what}.", what: what)
  defp error_message(%Ash.Error.Invalid{} = error), do: Exception.message(error)
  defp error_message(_), do: gettext("Something went wrong.")

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
