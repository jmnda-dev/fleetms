defmodule FleetmsWeb.AdminLive.Dashboard do
  @moduledoc """
  Platform admin: a tenant-less rollup of the whole platform.

  Reachable only by platform staff (`is_super_admin`). The figures come from
  `Fleetms.PlatformStats`, which reads across every tenant via the super-admin
  bypass. This is the landing page of the admin console; the per-client list
  lives at `/admin/organizations`.
  """
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    stats = Fleetms.PlatformStats.overview()

    {:ok, assign(socket, page_title: gettext("Platform Admin"), stats: stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin_shell active={:dashboard}>
      <Layouts.flash_group flash={@flash} />

      <.header>
        {gettext("Overview")}
        <:subtitle>{gettext("A snapshot across every client on the platform.")}</:subtitle>
      </.header>

      <div class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <.stat_card
          label={gettext("Organizations")}
          value={@stats.organizations}
          icon="fa-building"
          hint={
            gettext("%{b} business · %{i} individual",
              b: @stats.businesses,
              i: @stats.individuals
            )
          }
        />
        <.stat_card
          label={gettext("New this month")}
          value={@stats.new_organizations}
          icon="fa-arrow-trend-up"
          hint={gettext("Signed up in the last 30 days")}
        />
        <.stat_card
          label={gettext("User accounts")}
          value={@stats.users}
          icon="fa-users"
          hint={gettext("Across all organizations")}
        />
        <.stat_card
          label={gettext("Vehicles")}
          value={@stats.vehicles}
          icon="fa-truck"
          hint={gettext("Managed across every fleet")}
        />
        <.stat_card
          label={gettext("Open issues")}
          value={@stats.open_issues}
          icon="fa-triangle-exclamation"
          hint={gettext("Reported and not yet resolved")}
        />
        <.stat_card
          label={gettext("Open work orders")}
          value={@stats.open_work_orders}
          icon="fa-screwdriver-wrench"
          hint={gettext("Open or in progress")}
        />
      </div>

      <div class="mt-8 rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <div class="flex items-center justify-between border-b border-default px-4 py-3">
          <h2 class="text-sm font-semibold text-heading">{gettext("Recent signups")}</h2>
          <.link
            navigate={~p"/admin/organizations"}
            class="text-sm font-medium text-primary-600 hover:underline dark:text-primary-400"
          >
            {gettext("View all")} <.icon name="fa-arrow-right" class="ms-1 text-xs" />
          </.link>
        </div>
        <ul class="divide-y divide-default">
          <li
            :for={org <- @stats.recent_organizations}
            class="flex items-center justify-between px-4 py-3"
          >
            <div class="min-w-0">
              <p class="truncate font-medium text-heading">{org.name}</p>
              <p class="text-xs text-body">
                {Phoenix.Naming.humanize(org.account_type)} · {gettext("joined %{date}",
                  date: Calendar.strftime(org.inserted_at, "%Y-%m-%d")
                )}
              </p>
            </div>
            <.button size="xs" variant="secondary" navigate={~p"/o/#{org}"}>
              <.icon name="fa-right-to-bracket" class="me-1 text-xs" /> {gettext("Enter")}
            </.button>
          </li>
          <li :if={@stats.recent_organizations == []} class="px-4 py-10 text-center text-body">
            {gettext("No organizations yet.")}
          </li>
        </ul>
      </div>
    </Layouts.admin_shell>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :hint, :string, default: nil

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-base border border-default bg-white p-5 shadow-sm dark:bg-gray-800">
      <div class="flex items-start justify-between">
        <div>
          <p class="text-sm font-medium text-body">{@label}</p>
          <p class="mt-1 text-3xl font-bold text-heading">{@value}</p>
        </div>
        <span class="rounded-lg bg-primary-50 p-3 text-primary-600 dark:bg-primary-900/30 dark:text-primary-400">
          <.icon name={@icon} class="text-lg" />
        </span>
      </div>
      <p :if={@hint} class="mt-2 text-xs text-body">{@hint}</p>
    </div>
    """
  end
end
