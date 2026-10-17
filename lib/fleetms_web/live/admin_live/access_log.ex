defmodule FleetmsWeb.AdminLive.AccessLog do
  @moduledoc """
  Platform admin: the audit trail of platform staff entering client organizations.

  Every time a super-admin enters an org they aren't a member of (from the admin
  console), it's recorded. This page surfaces that history across all clients — an
  accountability record you can show customers ("here's exactly when our staff
  accessed your workspace"). Tenant-less, staff-only.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts

  @limit 50

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Access log"), page: 1) |> load()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, socket |> assign(page: String.to_integer(page)) |> load()}
  end

  defp load(socket) do
    page = socket.assigns.page

    data =
      Accounts.list_platform_access_logs!(%{},
        actor: socket.assigns.current_user,
        page: [limit: @limit, offset: (page - 1) * @limit, count: true]
      )

    assign(socket, entries: data.results, count: data.count || 0)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin_shell active={:access_log}>
      <Layouts.flash_group flash={@flash} />

      <.header>
        {gettext("Access log")}
        <:subtitle>
          {gettext("When platform staff entered a client's organization — %{n} events.",
            n: @count
          )}
        </:subtitle>
      </.header>

      <div class="mt-6 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-sm text-body">
            <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
              <tr>
                <th class="px-4 py-3 font-semibold">{gettext("When")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Staff member")}</th>
                <th class="px-4 py-3 font-semibold">{gettext("Organization")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={e <- @entries} class="border-t border-default">
                <td class="whitespace-nowrap px-4 py-3">
                  {Calendar.strftime(e.inserted_at, "%Y-%m-%d %H:%M")}
                </td>
                <td class="px-4 py-3">{e.admin_user && to_string(e.admin_user.email)}</td>
                <td class="px-4 py-3 font-medium text-heading">
                  {e.organization && e.organization.name}
                </td>
              </tr>
              <tr :if={@entries == []}>
                <td colspan="3" class="px-4 py-10 text-center text-body">
                  {gettext("No staff access recorded yet.")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          :if={total_pages(assigns) > 1}
          class="flex items-center justify-between border-t border-default p-4"
        >
          <.button
            size="sm"
            variant="secondary"
            disabled={@page <= 1}
            phx-click="paginate"
            phx-value-page={@page - 1}
          >
            <.icon name="fa-chevron-left" class="text-xs" /> {gettext("Previous")}
          </.button>
          <span class="text-sm text-body">
            {gettext("Page %{page} of %{total}", page: @page, total: total_pages(assigns))}
          </span>
          <.button
            size="sm"
            variant="secondary"
            disabled={@page >= total_pages(assigns)}
            phx-click="paginate"
            phx-value-page={@page + 1}
          >
            {gettext("Next")} <.icon name="fa-chevron-right" class="text-xs" />
          </.button>
        </div>
      </div>
    </Layouts.admin_shell>
    """
  end

  defp total_pages(assigns), do: max(1, ceil(assigns.count / @limit))
end
