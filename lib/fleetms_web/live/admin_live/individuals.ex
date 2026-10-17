defmodule FleetmsWeb.AdminLive.Individuals do
  @moduledoc """
  Platform admin: the individual clients managed in the shared pool.

  Individuals aren't organizations, so they don't appear on the Organizations
  page — they're listed here from their owner-scoped `ClientProfile`s. Tenant-less
  and staff-only (`is_super_admin`).
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts

  @impl true
  def mount(_params, _session, socket) do
    if Fleetms.FeatureFlags.individual_registration?() do
      individuals = Accounts.list_individual_clients!(actor: socket.assigns.current_user)

      {:ok,
       assign(socket, page_title: gettext("Individual Clients"), individuals: individuals)}
    else
      # The individual workflow is off — there's no pool to manage.
      {:ok,
       socket
       |> put_flash(:error, gettext("Individual client registration is disabled."))
       |> push_navigate(to: ~p"/admin")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin_shell active={:individuals}>
      <Layouts.flash_group flash={@flash} />

      <.header>
        {gettext("Individual Clients")}
        <:subtitle>
          {gettext("Personal-fleet clients managed in the shared pool — %{n} total.",
            n: length(@individuals)
          )}
        </:subtitle>
        <:actions>
          <.button navigate={~p"/admin/provision"}>
            <.icon name="fa-plus" class="me-1 text-xs" /> {gettext("Provision a client")}
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("Client")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Email")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("KYC")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Added")}</th>
                <th class="px-4 py-3 text-right font-semibold">
                  <span class="sr-only">{gettext("Actions")}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={profile <- @individuals} class="border-t border-default">
                <td class="px-4 py-3 font-medium text-heading">{client_name(profile)}</td>
                <td class="px-4 py-3">{profile.owner && profile.owner.email}</td>
                <td class="px-4 py-3"><.status_badge status={profile.status} /></td>
                <td class="px-4 py-3">{Calendar.strftime(profile.inserted_at, "%Y-%m-%d")}</td>
                <td class="px-4 py-3 text-right">
                  <.button
                    :if={profile.owner_id}
                    size="xs"
                    variant="secondary"
                    href={~p"/admin/individuals/#{profile.owner_id}/enter"}
                  >
                    <.icon name="fa-right-to-bracket" class="me-1 text-xs" /> {gettext("Manage")}
                  </.button>
                </td>
              </tr>
              <tr :if={@individuals == []}>
                <td colspan="5" class="px-4 py-10 text-center text-body">
                  {gettext("No individual clients yet.")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.admin_shell>
    """
  end

  # Prefer the client's user profile name; fall back to the KYC contact name.
  defp client_name(%{owner: %{profile: %{first_name: first} = p}}) when is_binary(first) do
    [first, p.last_name] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  defp client_name(profile), do: profile.contact_name

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded px-2 py-0.5 text-xs font-medium",
      @status == :pending && "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300",
      @status == :verified &&
        "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
      @status == :rejected && "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"
    ]}>
      {Phoenix.Naming.humanize(@status)}
    </span>
    """
  end
end
