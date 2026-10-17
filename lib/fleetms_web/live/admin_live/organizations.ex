defmodule FleetmsWeb.AdminLive.Organizations do
  @moduledoc """
  Platform admin: a cross-organization overview of every client on the platform.

  Tenant-less and reachable only by platform staff (`is_super_admin`), who read
  across all tenants via the super-admin policy bypass on `Organization`. The
  rollup dashboard lives at `/admin`; provisioning comes later.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts

  @impl true
  def mount(_params, _session, socket) do
    orgs =
      [actor: socket.assigns.current_user, load: [:member_count]]
      |> Accounts.list_organizations!()
      # The individuals pool is internal infrastructure, not a client org.
      |> Enum.reject(&Fleetms.Individuals.pool?/1)
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

    {:ok,
     assign(socket,
       page_title: gettext("Platform Admin"),
       all_organizations: orgs,
       organizations: orgs,
       query: ""
     )}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply,
     assign(socket, query: q, organizations: filter(socket.assigns.all_organizations, q))}
  end

  def handle_event("enter", %{"id" => org_id}, socket) do
    case Enum.find(socket.assigns.all_organizations, &(&1.id == org_id)) do
      nil ->
        {:noreply,
         put_flash(socket, :error, gettext("That organization is no longer available."))}

      org ->
        # Audit the deliberate entry, then drop into the org as staff. A best-effort
        # log: a failure here must not block acting on the client's behalf.
        record_access(socket.assigns.current_user, org)
        {:noreply, push_navigate(socket, to: ~p"/o/#{org}")}
    end
  end

  defp record_access(user, org) do
    Accounts.record_platform_access(%{organization_id: org.id}, actor: user)
  rescue
    _ -> :ok
  end

  # Small client-side filter — the org list is at most a few hundred rows.
  defp filter(orgs, q) when q in [nil, ""], do: orgs

  defp filter(orgs, q) do
    needle = String.downcase(q)

    Enum.filter(orgs, fn org ->
      String.contains?(String.downcase(org.name), needle) or
        String.contains?(String.downcase(org.public_id), needle)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin_shell active={:organizations}>
      <Layouts.flash_group flash={@flash} />

      <.header>
        {gettext("Organizations")}
        <:subtitle>
          {gettext("Every client on the platform — %{n} total.", n: length(@all_organizations))}
        </:subtitle>
        <:actions>
          <.button navigate={~p"/admin/provision"}>
            <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Provision a client")}
          </.button>
        </:actions>
      </.header>

      <form phx-change="search" phx-submit="search" class="mt-4 w-full sm:max-w-sm">
        <div class="relative">
          <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <.icon name="fa-magnifying-glass" class="text-body text-sm" />
          </div>
          <input
            type="search"
            name="q"
            value={@query}
            phx-debounce="200"
            placeholder={gettext("Search by name or ID…")}
            class="block w-full rounded-base border border-default-medium bg-white p-2 pl-10 text-sm text-heading focus:border-brand focus:ring-brand dark:bg-gray-800"
          />
        </div>
      </form>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Organization")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Type")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Members")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Created")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("ID")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={org <- @organizations} class="border-t border-default">
                <td class="px-4 py-3 font-medium text-heading">
                  <.link
                    navigate={~p"/admin/organizations/#{org.id}"}
                    class="hover:text-primary-600 hover:underline dark:hover:text-primary-400"
                  >
                    {org.name}
                  </.link>
                </td>
                <td class="px-4 py-3"><.type_badge type={org.account_type} /></td>
                <td class="px-4 py-3"><.status_badge status={org.status} /></td>
                <td class="px-4 py-3">{org.member_count}</td>
                <td class="px-4 py-3">{Calendar.strftime(org.inserted_at, "%Y-%m-%d")}</td>
                <td class="px-4 py-3 font-mono text-xs text-gray-500 dark:text-gray-400">
                  {org.public_id}
                </td>
                <td class="px-4 py-3 text-right">
                  <.button size="xs" variant="secondary" phx-click="enter" phx-value-id={org.id}>
                    <.icon name="fa-right-to-bracket" class="me-1 text-xs" /> {gettext("Enter")}
                  </.button>
                </td>
              </tr>
              <tr :if={@organizations == []}>
                <td colspan="7" class="px-4 py-10 text-center text-body">
                  {if @query == "",
                    do: gettext("No organizations yet."),
                    else: gettext("No organizations match your search.")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.admin_shell>
    """
  end

  attr :type, :atom, required: true

  defp type_badge(assigns) do
    ~H"""
    <span class={[
      "rounded px-2 py-0.5 text-xs font-medium",
      @type == :individual && "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300",
      @type == :business && "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300"
    ]}>
      {Phoenix.Naming.humanize(@type)}
    </span>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded-full px-2 py-0.5 text-xs font-medium",
      @status == :active && "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
      @status == :suspended && "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"
    ]}>
      {Phoenix.Naming.humanize(@status)}
    </span>
    """
  end
end
