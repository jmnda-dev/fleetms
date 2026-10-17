defmodule FleetmsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality used by your application.

  The `app/1` layout is the application shell for all *internal* (authenticated)
  pages. It renders the Flowbite Admin Dashboard chrome — a fixed top navbar and
  a collapsible sidebar — around the page content.

  Public pages (Sign In, Sign Up, Password Reset, etc.) should NOT use this
  layout; they render without the dashboard chrome.

  Interactivity (sidebar collapse, dark mode, dropdowns, the mobile drawer) is
  driven by Flowbite + `assets/js/layout.js`. The element ids and `data-*`
  attributes here are the contract those scripts rely on — keep them in sync.
  """
  use FleetmsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  The application shell for internal pages: fixed navbar + collapsible sidebar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :organizations, :list,
    default: [],
    doc: "the organizations the current user belongs to (for the org switcher)"

  attr :unread_notifications_count, :integer,
    default: 0,
    doc: "unread notification count for the navbar bell badge"

  attr :recent_notifications, :list,
    default: [],
    doc: "the recipient's most recent notifications for the bell dropdown"

  attr :notifications_open, :boolean,
    default: false,
    doc: "whether the bell dropdown is open (server-driven so it survives re-renders)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%!-- Keyboard users can jump past the nav straight to the page content. --%>
    <a
      href="#main-content"
      class="sr-only rounded-base bg-brand px-4 py-2 text-sm font-medium text-white focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60]"
    >
      {gettext("Skip to content")}
    </a>
    <.navbar
      current_scope={@current_scope}
      unread_notifications_count={@unread_notifications_count}
      recent_notifications={@recent_notifications}
      notifications_open={@notifications_open}
    />

    <.live_component
      :if={@current_scope}
      module={FleetmsWeb.GlobalSearch}
      id="global-search"
      current_scope={@current_scope}
    />

    <div class="flex overflow-hidden bg-gray-100 pt-[62px] dark:bg-gray-900">
      <.sidebar current_scope={@current_scope} organizations={@organizations} />

      <div
        id="main-content"
        tabindex="-1"
        class="relative h-full w-full overflow-x-hidden bg-gray-100 outline-none dark:bg-gray-900 lg:ms-64"
      >
        <div
          :if={@current_scope && @current_scope.staff_access?}
          class="flex flex-wrap items-center justify-between gap-2 border-b border-amber-300 bg-amber-100 px-4 py-2 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-900/40 dark:text-amber-200 sm:px-6 lg:px-8"
        >
          <span :if={@current_scope.on_behalf_of}>
            <.icon name="fa-user-shield" class="me-1" />
            {gettext("Managing %{name}'s fleet as platform staff.",
              name: @current_scope.on_behalf_label || gettext("an individual client")
            )}
          </span>
          <span :if={!@current_scope.on_behalf_of}>
            <.icon name="fa-user-shield" class="me-1" />
            {gettext("Viewing %{org} as platform staff.", org: @current_scope.organization.name)}
          </span>
          <.link
            :if={@current_scope.on_behalf_of}
            href={~p"/admin/exit-individual"}
            class="font-semibold underline hover:no-underline"
          >
            {gettext("Exit")}
          </.link>
          <.link
            :if={!@current_scope.on_behalf_of}
            navigate={~p"/admin"}
            class="font-semibold underline hover:no-underline"
          >
            {gettext("Exit to admin")}
          </.link>
        </div>
        <main class="min-h-[calc(100vh-62px)] px-4 py-6 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  # ---------------------------------------------------------------------------
  # Navbar
  # ---------------------------------------------------------------------------

  attr :current_scope, :map, default: nil
  attr :unread_notifications_count, :integer, default: 0
  attr :recent_notifications, :list, default: []
  attr :notifications_open, :boolean, default: false

  defp navbar(assigns) do
    ~H"""
    <nav class="fixed z-30 flex h-16 w-full items-center border-b border-gray-200 bg-white px-4 dark:border-gray-700 dark:bg-gray-800">
      <div class="flex w-full items-center justify-between">
        <div class="flex items-center justify-start">
          <%!-- Desktop: collapse/expand the sidebar (handled by layout.js) --%>
          <button
            id="togglSidebarButton"
            aria-expanded="true"
            aria-controls="sidebar"
            aria-label={gettext("Toggle sidebar")}
            phx-update="ignore"
            class="me-2 hidden cursor-pointer rounded-sm p-1.5 text-gray-600 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white lg:inline"
          >
            <i
              class="fa-solid fa-bars-staggered h-7 w-7 text-xl leading-7"
              data-sidebar-toggle-collapse-icon
            >
            </i>
            <i
              class="fa-solid fa-bars hidden h-7 w-7 text-xl leading-7"
              data-sidebar-toggle-expand-icon
            >
            </i>
          </button>

          <%!-- Mobile: open the sidebar as a drawer. A dedicated hook owns a single
               Flowbite Drawer instance (no `data-drawer-*` auto-wiring) so closing it
               never leaves a stacked backdrop behind. --%>
          <button
            id="mobile-sidebar-toggle"
            phx-hook="SidebarDrawer"
            phx-update="ignore"
            aria-expanded="false"
            aria-controls="sidebar"
            aria-label={gettext("Open menu")}
            class="me-2 inline cursor-pointer rounded-sm p-1.5 text-gray-600 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white lg:hidden"
          >
            <i class="fa-solid fa-bars h-7 w-7 text-xl leading-7"></i>
          </button>

          <.link navigate={~p"/"} class="mr-4 flex items-center">
            <img src={~p"/images/logo_light.svg"} class="h-10 dark:hidden" alt={gettext("FleetMS")} />
            <img
              src={~p"/images/logo_dark.svg"}
              class="hidden h-10 dark:block"
              alt={gettext("FleetMS")}
            />
          </.link>

          <%!-- Opens the ⌘K command palette (rendered in Layouts.app). --%>
          <button
            type="button"
            data-cmdk-open
            class="ms-6 hidden items-center gap-2 rounded-lg border border-gray-300 bg-gray-50 px-3 py-2.5 text-sm text-gray-500 hover:bg-gray-100 focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-400 dark:hover:bg-gray-600 lg:flex lg:w-80"
          >
            <i class="fa-solid fa-magnifying-glass"></i>
            <span class="flex-1 text-left">{gettext("Search")}</span>
            <kbd class="rounded border border-gray-300 px-1.5 py-0.5 text-xs dark:border-gray-500">
              ⌘K
            </kbd>
          </button>
        </div>

        <div class="flex items-center lg:order-2">
          <div class="flex items-center space-x-1 sm:pe-3">
            <%!-- Compact search trigger for phones/tablets — the wide ⌘K bar is
                  lg-only, so without this there'd be no way to open search on mobile. --%>
            <button
              type="button"
              data-cmdk-open
              aria-label={gettext("Search")}
              class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-700 lg:hidden"
            >
              <i class="fa-solid fa-magnifying-glass text-xl"></i>
            </button>

            <.notifications_menu
              current_scope={@current_scope}
              unread_count={@unread_notifications_count}
              notifications={@recent_notifications}
              open={@notifications_open}
            />

            <%!-- Dark mode toggle. layout.js owns the icon visibility, so tell
                 LiveView not to patch this subtree (a bell-click diff would
                 otherwise reassert the static `hidden` class on both icons). --%>
            <button
              id="theme-toggle"
              type="button"
              phx-update="ignore"
              class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
            >
              <span class="sr-only">{gettext("Toggle dark mode")}</span>
              <i id="theme-toggle-dark-icon" class="fa-solid fa-moon hidden text-xl"></i>
              <i id="theme-toggle-light-icon" class="fa-solid fa-sun hidden text-xl"></i>
            </button>

            <.theme_selector />
          </div>

          <div class="mx-2 hidden h-5 w-px bg-gray-200 dark:bg-gray-700 sm:block"></div>

          <%!-- User menu (handled by Flowbite dropdown) --%>
          <button
            type="button"
            class="flex items-center gap-2 rounded-full p-1 text-sm text-gray-700 hover:bg-gray-100 focus:ring-2 focus:ring-gray-300 dark:text-gray-300 dark:hover:bg-gray-700 dark:focus:ring-gray-600"
            id="user-menu-button"
            aria-expanded="false"
            data-dropdown-toggle="accountDropdown"
          >
            <span class="sr-only">{gettext("Open user menu")}</span>
            <i class="fa-solid fa-circle-user text-3xl text-gray-400"></i>
            <span class="hidden font-medium sm:block">{user_label(@current_scope)}</span>
            <i class="fa-solid fa-chevron-down hidden text-xs sm:block"></i>
          </button>

          <div
            id="accountDropdown"
            class="z-50 hidden w-56 list-none divide-y divide-gray-100 rounded-lg bg-white text-base shadow-sm dark:divide-gray-600 dark:bg-gray-700"
          >
            <div class="px-4 py-3">
              <span class="block text-sm font-semibold text-gray-900 dark:text-white">
                {user_label(@current_scope)}
              </span>
              <span class="block truncate text-sm text-gray-500 dark:text-gray-400">
                {user_email(@current_scope)}
              </span>
            </div>
            <ul class="py-1 text-sm text-gray-700 dark:text-gray-300">
              <.menu_link navigate={~p"/o/#{@current_scope.organization}/profile"} icon="fa-user">
                {gettext("My Profile")}
              </.menu_link>
              <.menu_link navigate={~p"/o/#{@current_scope.organization}/settings"} icon="fa-gear">
                {gettext("Account Settings")}
              </.menu_link>
              <.menu_link
                :if={Fleetms.Scope.owner?(@current_scope)}
                navigate={~p"/o/#{@current_scope.organization}/organization-settings"}
                icon="fa-building-gear"
              >
                {gettext("Organization Settings")}
              </.menu_link>
              <.menu_link
                :if={@current_scope.user && @current_scope.user.is_super_admin}
                navigate={~p"/admin"}
                icon="fa-shield-halved"
              >
                {gettext("Platform Admin")}
              </.menu_link>
            </ul>
            <ul class="py-1 text-sm text-gray-700 dark:text-gray-300">
              <li>
                <.link
                  href={~p"/sign-out"}
                  method="delete"
                  data-confirm={gettext("Sign out of FleetMS?")}
                  class="flex items-center gap-2 px-4 py-2 text-red-600 hover:bg-red-50 dark:text-red-500 dark:hover:bg-gray-600"
                >
                  <i class="fa-solid fa-arrow-right-from-bracket w-4 text-center"></i> {gettext(
                    "Sign Out"
                  )}
                </.link>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  attr :icon, :string, required: true
  attr :rest, :global, include: ~w(href navigate patch)
  slot :inner_block, required: true

  defp menu_link(assigns) do
    ~H"""
    <li>
      <.link
        class="flex items-center gap-2 px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white"
        {@rest}
      >
        <i class={["fa-solid w-4 text-center text-gray-500 dark:text-gray-400", @icon]}></i>
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end

  # ---------------------------------------------------------------------------
  # Notifications bell + dropdown
  # ---------------------------------------------------------------------------

  attr :current_scope, :map, default: nil
  attr :unread_count, :integer, required: true
  attr :notifications, :list, required: true
  attr :open, :boolean, default: false

  defp notifications_menu(assigns) do
    ~H"""
    <div class="relative" phx-click-away={@open && "notifications:close"}>
      <button
        type="button"
        id="notifications-menu-button"
        phx-click="notifications:toggle"
        aria-expanded={to_string(@open)}
        class="relative rounded-lg p-2 text-gray-500 hover:bg-gray-100 hover:text-gray-900 focus:ring-2 focus:ring-gray-300 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white dark:focus:ring-gray-600"
      >
        <span class="sr-only">{gettext("View notifications")}</span>
        <i class="fa-solid fa-bell text-xl"></i>
        <span
          :if={@unread_count > 0}
          class="absolute -right-0.5 -top-0.5 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-semibold leading-none text-white"
        >
          {if @unread_count > 99, do: "99+", else: @unread_count}
        </span>
      </button>

      <div
        id="notificationDropdown"
        hidden={!@open}
        class="absolute right-0 z-50 mt-2 w-80 max-w-[calc(100vw-1rem)] overflow-hidden rounded-lg bg-white shadow-md ring-1 ring-black/5 dark:bg-gray-800 dark:ring-white/10"
      >
        <div class="flex items-center justify-between border-b border-gray-100 px-4 py-2 dark:border-gray-700">
          <span class="text-sm font-semibold text-gray-900 dark:text-white">
            {gettext("Notifications")}
          </span>
          <button
            :if={@unread_count > 0}
            type="button"
            phx-click="notifications:mark-all-read"
            class="text-xs font-medium text-primary-600 hover:underline dark:text-primary-400"
          >
            {gettext("Mark all read")}
          </button>
        </div>

        <div class="max-h-96 divide-y divide-gray-100 overflow-y-auto dark:divide-gray-700">
          <p
            :if={@notifications == []}
            class="px-4 py-8 text-center text-sm text-gray-500 dark:text-gray-400"
          >
            {gettext("You're all caught up.")}
          </p>

          <button
            :for={notification <- @notifications}
            type="button"
            phx-click="notifications:open"
            phx-value-id={notification.id}
            class={[
              "flex w-full items-start gap-3 px-4 py-3 text-left hover:bg-gray-50 dark:hover:bg-gray-700",
              is_nil(notification.read_at) && "bg-primary-50/60 dark:bg-gray-700/40"
            ]}
          >
            <span class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-300">
              <i class={["fa-solid text-sm", notification_icon(notification.type)]}></i>
            </span>
            <span class="min-w-0 flex-1">
              <span class="block truncate text-sm font-medium text-gray-900 dark:text-white">
                {notification.title}
              </span>
              <span
                :if={notification.body not in [nil, ""]}
                class="block truncate text-xs text-gray-500 dark:text-gray-400"
              >
                {notification.body}
              </span>
              <span class="mt-0.5 block text-[11px] text-gray-400 dark:text-gray-500">
                {time_ago(notification.inserted_at)}
              </span>
            </span>
            <span
              :if={is_nil(notification.read_at)}
              class="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-primary-500"
              aria-hidden="true"
            >
            </span>
          </button>
        </div>

        <.link
          :if={@current_scope}
          navigate={~p"/o/#{@current_scope.organization}/notifications"}
          class="block border-t border-gray-100 px-4 py-2.5 text-center text-sm font-medium text-primary-600 hover:bg-gray-50 dark:border-gray-700 dark:text-primary-400 dark:hover:bg-gray-700"
        >
          {gettext("See all notifications")}
        </.link>
      </div>
    </div>
    """
  end

  # Maps a notification `type` (producer category) to a Font Awesome icon.
  defp notification_icon("issue_assigned"), do: "fa-user-tag"
  defp notification_icon("issue_resolved"), do: "fa-circle-check"
  defp notification_icon("issue_closed"), do: "fa-circle-xmark"
  defp notification_icon(_type), do: "fa-bell"

  # Compact "time ago" label for the dropdown.
  defp time_ago(nil), do: ""

  defp time_ago(%DateTime{} = datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      seconds < 60 -> gettext("just now")
      seconds < 3600 -> gettext("%{n}m ago", n: div(seconds, 60))
      seconds < 86_400 -> gettext("%{n}h ago", n: div(seconds, 3600))
      seconds < 604_800 -> gettext("%{n}d ago", n: div(seconds, 86_400))
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  # ---------------------------------------------------------------------------
  # Color theme selector
  # ---------------------------------------------------------------------------
  # Picks the accent/neutral palette (midnight / enterprise / forest). This is the
  # `data-theme` palette switch, separate from the dark-mode toggle above. The
  # actual switching + persistence + active-row tick is done in layout.js via
  # the `data-set-theme` / `data-theme-check` hooks below.

  @doc """
  Dropdown that switches the color palette (midnight / enterprise / forest).

  Used in the dashboard navbar and the public landing header. Relies on
  `assets/js/layout.js` (the `data-set-theme` / `data-theme-check` hooks).
  """
  def theme_selector(assigns) do
    ~H"""
    <button
      id="theme-selector-button"
      type="button"
      data-dropdown-toggle="themeDropdown"
      data-dropdown-placement="bottom"
      class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
    >
      <span class="sr-only">{gettext("Change color theme")}</span>
      <i class="fa-solid fa-palette text-xl"></i>
    </button>

    <div
      id="themeDropdown"
      class="z-50 hidden w-48 list-none rounded-lg bg-white text-base shadow-sm dark:bg-gray-700"
    >
      <div class="px-4 py-2 text-xs font-semibold uppercase tracking-wide text-gray-400 dark:text-gray-400">
        {gettext("Color theme")}
      </div>
      <ul class="pb-1 text-sm text-gray-700 dark:text-gray-300">
        <.theme_option theme="midnight" swatch="#001a72" label={gettext("Midnight")} />
        <.theme_option theme="enterprise" swatch="#0891b2" label={gettext("Enterprise")} />
        <.theme_option theme="forest" swatch="#059669" label={gettext("Forest")} />
      </ul>
    </div>
    """
  end

  attr :theme, :string, required: true
  attr :swatch, :string, required: true
  attr :label, :string, required: true

  defp theme_option(assigns) do
    ~H"""
    <li>
      <button
        type="button"
        data-set-theme={@theme}
        class="flex w-full items-center gap-3 px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white"
      >
        <span
          class="h-4 w-4 shrink-0 rounded-full ring-1 ring-black/10"
          style={"background-color: #{@swatch}"}
        >
        </span>
        <span class="flex-1 text-left">{@label}</span>
        <i
          class="fa-solid fa-check invisible text-xs text-primary-600 dark:text-primary-400"
          data-theme-check
        >
        </i>
      </button>
    </li>
    """
  end

  @doc """
  Minimal standalone page wrapper for tenant-less authenticated pages (org picker
  and org creation). Provides the logo, dark-mode + theme toggles and sign-out,
  but none of the dashboard chrome (there is no organization context yet).
  """
  attr :current_user, :any,
    default: nil,
    doc: "the signed-in user, so the shell can show who they are and a staff shortcut"

  slot :inner_block, required: true

  def org_shell(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-gray-100 dark:bg-gray-900">
      <header class="flex items-center justify-between border-b border-gray-200 bg-white px-4 py-3 dark:border-gray-700 dark:bg-gray-800">
        <.link navigate={~p"/"} class="flex items-center">
          <img src={~p"/images/logo_light.svg"} class="h-8 dark:hidden" alt={gettext("FleetMS")} />
          <img src={~p"/images/logo_dark.svg"} class="hidden h-8 dark:block" alt={gettext("FleetMS")} />
        </.link>
        <div class="flex items-center gap-1">
          <span
            :if={@current_user}
            class="mr-1 hidden max-w-[16rem] truncate text-sm text-gray-500 sm:inline dark:text-gray-400"
            title={to_string(@current_user.email)}
          >
            {to_string(@current_user.email)}
          </span>
          <.link
            :if={@current_user && @current_user.is_super_admin}
            navigate={~p"/admin"}
            class="mr-1 inline-flex items-center gap-1.5 rounded-lg border border-brand-subtle bg-brand-softer px-3 py-2 text-sm font-medium text-fg-brand-strong hover:bg-brand-soft"
          >
            <i class="fa-solid fa-shield-halved text-xs"></i>
            {gettext("Platform Admin")}
          </.link>
          <button
            id="theme-toggle"
            type="button"
            class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
          >
            <span class="sr-only">{gettext("Toggle dark mode")}</span>
            <i id="theme-toggle-dark-icon" class="fa-solid fa-moon hidden text-xl"></i>
            <i id="theme-toggle-light-icon" class="fa-solid fa-sun hidden text-xl"></i>
          </button>
          <.theme_selector />
          <.link
            href={~p"/sign-out"}
            method="delete"
            data-confirm={gettext("Sign out of FleetMS?")}
            class="ml-2 rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-white"
          >
            {gettext("Sign out")}
          </.link>
        </div>
      </header>
      <main class="flex flex-1 items-center justify-center px-4 py-10">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  @doc """
  Full-width shell for the tenant-less platform admin area (`/admin`, staff only).
  Like `org_shell` but wide, with an "Admin" marker and a way back into the app.
  """
  attr :active, :atom,
    default: nil,
    doc: "which admin tab to highlight (:dashboard | :organizations)"

  slot :inner_block, required: true

  def admin_shell(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-gray-100 dark:bg-gray-900">
      <header class="flex items-center justify-between border-b border-gray-200 bg-white px-4 py-3 dark:border-gray-700 dark:bg-gray-800">
        <div class="flex items-center gap-3">
          <.link navigate={~p"/admin"} class="flex items-center">
            <img src={~p"/images/logo_light.svg"} class="h-8 dark:hidden" alt={gettext("FleetMS")} />
            <img
              src={~p"/images/logo_dark.svg"}
              class="hidden h-8 dark:block"
              alt={gettext("FleetMS")}
            />
          </.link>
          <span class="rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-semibold text-amber-800 dark:bg-amber-900/40 dark:text-amber-300">
            {gettext("Platform Admin")}
          </span>
        </div>
        <div class="flex items-center gap-1">
          <%!-- Plain link (href), not navigate: the flags UI is a forwarded Plug page. --%>
          <.link
            href="/admin/feature-flags"
            class="rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-white"
          >
            <.icon name="fa-flag" class="me-1 text-xs" /> {gettext("Feature flags")}
          </.link>
          <.link
            navigate={~p"/"}
            class="rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-white"
          >
            <.icon name="fa-arrow-left" class="me-1 text-xs" /> {gettext("Back to app")}
          </.link>
          <button
            id="theme-toggle"
            type="button"
            class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
          >
            <span class="sr-only">{gettext("Toggle dark mode")}</span>
            <i id="theme-toggle-dark-icon" class="fa-solid fa-moon hidden text-xl"></i>
            <i id="theme-toggle-light-icon" class="fa-solid fa-sun hidden text-xl"></i>
          </button>
          <.theme_selector />
          <.link
            href={~p"/sign-out"}
            method="delete"
            data-confirm={gettext("Sign out of FleetMS?")}
            class="ml-2 rounded-lg px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 hover:text-gray-900 dark:text-gray-300 dark:hover:bg-gray-700 dark:hover:text-white"
          >
            {gettext("Sign out")}
          </.link>
        </div>
      </header>
      <nav class="border-b border-gray-200 bg-white px-4 dark:border-gray-700 dark:bg-gray-800 sm:px-6 lg:px-8">
        <div class="mx-auto flex w-full max-w-7xl gap-1">
          <.admin_tab navigate={~p"/admin"} active={@active == :dashboard}>
            <.icon name="fa-gauge-high" class="me-1.5 text-xs" /> {gettext("Overview")}
          </.admin_tab>
          <.admin_tab navigate={~p"/admin/organizations"} active={@active == :organizations}>
            <.icon name="fa-building" class="me-1.5 text-xs" /> {gettext("Organizations")}
          </.admin_tab>
          <.admin_tab
            :if={Fleetms.FeatureFlags.individual_registration?()}
            navigate={~p"/admin/individuals"}
            active={@active == :individuals}
          >
            <.icon name="fa-user" class="me-1.5 text-xs" /> {gettext("Individuals")}
          </.admin_tab>
          <.admin_tab navigate={~p"/admin/access-log"} active={@active == :access_log}>
            <.icon name="fa-clock-rotate-left" class="me-1.5 text-xs" /> {gettext("Access log")}
          </.admin_tab>
        </div>
      </nav>
      <main class="mx-auto w-full max-w-7xl flex-1 px-4 py-8 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp admin_tab(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "-mb-px border-b-2 px-3 py-3 text-sm font-medium",
        @active &&
          "border-primary-600 text-primary-700 dark:border-primary-400 dark:text-primary-300",
        !@active &&
          "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Standalone shell for unauthenticated auth pages (sign in, register, password
  reset). Centers a card and offers the dark-mode + theme controls; no sign-out.
  """
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def auth_shell(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col bg-gray-50 dark:bg-gray-900">
      <header class="flex items-center justify-between px-4 py-3">
        <.link navigate={~p"/"} class="flex items-center">
          <img src={~p"/images/logo_light.svg"} class="h-8 dark:hidden" alt={gettext("FleetMS")} />
          <img src={~p"/images/logo_dark.svg"} class="hidden h-8 dark:block" alt={gettext("FleetMS")} />
        </.link>
        <div class="flex items-center gap-1">
          <button
            id="theme-toggle"
            type="button"
            class="rounded-lg p-2 text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
          >
            <span class="sr-only">{gettext("Toggle dark mode")}</span>
            <i id="theme-toggle-dark-icon" class="fa-solid fa-moon hidden text-xl"></i>
            <i id="theme-toggle-light-icon" class="fa-solid fa-sun hidden text-xl"></i>
          </button>
          <.theme_selector />
        </div>
      </header>
      <main class="flex flex-1 items-center justify-center px-4 py-8">
        <div class="w-full max-w-md">
          <.flash_group flash={@flash} />
          <div class="rounded-lg bg-white p-6 shadow-sm dark:bg-gray-800 sm:p-8">
            {render_slot(@inner_block)}
          </div>
        </div>
      </main>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Sidebar
  # ---------------------------------------------------------------------------

  attr :current_scope, :map, required: true
  attr :organizations, :list, default: []

  # Workspace/organization switcher at the top of the sidebar. Switching is just
  # navigation to another org's URL, which re-runs the tenant-resolution hook.
  defp org_switcher(assigns) do
    ~H"""
    <div class="mb-4">
      <button
        id="orgSwitcherButton"
        type="button"
        data-dropdown-toggle="orgSwitcherDropdown"
        class="flex w-full items-center justify-between rounded-lg p-2 hover:bg-gray-50 focus:outline-none focus:ring-4 focus:ring-gray-200 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
      >
        <span class="flex min-w-0 items-center gap-3">
          <span class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand text-sm font-semibold text-white dark:text-primary-900">
            {label_initial(Fleetms.Scope.workspace_name(@current_scope))}
          </span>
          <span class="min-w-0 text-left" data-sidebar-collapse-hide>
            <span class="block truncate font-semibold leading-none text-gray-900 dark:text-white">
              {Fleetms.Scope.workspace_name(@current_scope)}
            </span>
            <span class="block text-xs text-gray-500 dark:text-gray-400">
              {org_role_label(@current_scope)}
            </span>
          </span>
        </span>
        <i
          class="fa-solid fa-chevron-down text-xs text-gray-500 dark:text-gray-400"
          data-sidebar-collapse-hide
        >
        </i>
      </button>

      <div
        id="orgSwitcherDropdown"
        class="z-50 hidden w-60 divide-y divide-gray-100 rounded-lg bg-white shadow-sm dark:divide-gray-600 dark:bg-gray-700"
      >
        <ul class="max-h-64 overflow-y-auto py-1">
          <li :for={org <- @organizations}>
            <.link
              navigate={~p"/o/#{org}"}
              class="flex items-center gap-3 px-4 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-600"
            >
              <span class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-gray-100 text-xs font-semibold text-gray-700 dark:bg-gray-600 dark:text-gray-200">
                {label_initial(switch_label(org, @current_scope))}
              </span>
              <span class="flex-1 truncate text-gray-900 dark:text-white">
                {switch_label(org, @current_scope)}
              </span>
              <i
                :if={org.id == @current_scope.organization.id}
                class="fa-solid fa-check text-xs text-fg-brand"
              >
              </i>
            </.link>
          </li>
        </ul>
        <div class="py-1">
          <.link
            navigate={~p"/orgs/new"}
            class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-600"
          >
            <i class="fa-solid fa-plus w-4 text-center"></i> {gettext("Create organization")}
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp label_initial(name) when is_binary(name) and name != "" do
    name |> String.first() |> String.upcase()
  end

  defp label_initial(_), do: "?"

  # The switcher label for an org row: an individual client's own name for the
  # pool, the org name otherwise.
  defp switch_label(org, scope) do
    if Fleetms.Individuals.pool?(org), do: Fleetms.Scope.workspace_name(scope), else: org.name
  end

  defp org_role_label(scope) do
    if Fleetms.Scope.owner?(scope), do: gettext("Owner"), else: gettext("Member")
  end

  attr :current_scope, :map, required: true
  attr :organizations, :list, default: []

  defp sidebar(assigns) do
    ~H"""
    <aside
      id="sidebar"
      class="fixed left-0 top-0 z-40 h-screen w-64 -translate-x-full transition-transform duration-75 lg:z-0 lg:translate-x-0 lg:pt-16 lg:transition-[width]"
      aria-label={gettext("Sidebar")}
    >
      <div class="h-full overflow-y-auto border-r border-gray-200 bg-white px-3 py-4 dark:border-gray-700 dark:bg-gray-800">
        <.org_switcher current_scope={@current_scope} organizations={@organizations} />

        <ul class="space-y-2">
          <.nav_link
            icon="fa-chart-pie"
            label={gettext("Dashboard")}
            navigate={~p"/o/#{@current_scope.organization}"}
          />

          <.nav_link
            icon="fa-calendar-days"
            label={gettext("Calendar")}
            navigate={~p"/o/#{@current_scope.organization}/calendar"}
          />

          <.nav_group
            :if={
              Fleetms.Scope.has_any_permission?(@current_scope, [
                :view_vehicles,
                :view_assignments,
                :view_renewals,
                :view_drivers
              ])
            }
            id="dropdown-vehicles"
            icon="fa-truck"
            label={gettext("Vehicles")}
          >
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_vehicles)}
              icon="fa-list"
              label={gettext("All Vehicles")}
              navigate={~p"/o/#{@current_scope.organization}/vehicles"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_assignments)}
              icon="fa-user-check"
              label={gettext("Assignments")}
              navigate={~p"/o/#{@current_scope.organization}/assignments"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_renewals)}
              icon="fa-arrows-rotate"
              label={gettext("Renewals")}
              navigate={~p"/o/#{@current_scope.organization}/renewals"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_drivers)}
              icon="fa-id-card"
              label={gettext("Drivers")}
              navigate={~p"/o/#{@current_scope.organization}/drivers"}
            />
          </.nav_group>

          <.nav_group
            :if={
              Fleetms.Scope.has_any_permission?(@current_scope, [
                :view_inspections,
                :view_inspection_forms,
                :view_inspection_schedules
              ])
            }
            id="dropdown-inspections"
            icon="fa-clipboard-check"
            label={gettext("Inspections")}
          >
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_inspection_forms)}
              icon="fa-file-lines"
              label={gettext("Inspection Forms")}
              navigate={~p"/o/#{@current_scope.organization}/inspection-forms"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_inspections)}
              icon="fa-clipboard-list"
              label={gettext("Inspections")}
              navigate={~p"/o/#{@current_scope.organization}/inspections"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_inspection_schedules)}
              icon="fa-calendar-days"
              label={gettext("Schedules")}
              navigate={~p"/o/#{@current_scope.organization}/inspection-schedules"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_inspections)}
              icon="fa-clock"
              label={gettext("Due Inspections")}
              navigate={~p"/o/#{@current_scope.organization}/inspection-assignments"}
            />
          </.nav_group>

          <.nav_link
            :if={Fleetms.Scope.has_permission?(@current_scope, :view_issues)}
            icon="fa-circle-exclamation"
            label={gettext("Issues")}
            navigate={~p"/o/#{@current_scope.organization}/issues"}
          />

          <.nav_group
            :if={
              Fleetms.Scope.has_any_permission?(@current_scope, [
                :view_service_reminders,
                :view_work_orders,
                :view_service_tasks,
                :view_service_groups,
                :view_vendors
              ])
            }
            id="dropdown-maintenance"
            icon="fa-screwdriver-wrench"
            label={gettext("Maintenance")}
          >
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_service_tasks)}
              icon="fa-list-check"
              label={gettext("Service Tasks")}
              navigate={~p"/o/#{@current_scope.organization}/service-tasks"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_service_groups)}
              icon="fa-layer-group"
              label={gettext("Service Groups")}
              navigate={~p"/o/#{@current_scope.organization}/service-groups"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_service_reminders)}
              icon="fa-bell"
              label={gettext("Service Reminders")}
              navigate={~p"/o/#{@current_scope.organization}/service-reminders"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_work_orders)}
              icon="fa-file-invoice"
              label={gettext("Work Orders")}
              navigate={~p"/o/#{@current_scope.organization}/work-orders"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_vendors)}
              icon="fa-store"
              label={gettext("Vendors")}
              navigate={~p"/o/#{@current_scope.organization}/vendors"}
            />
          </.nav_group>

          <.nav_group
            :if={
              Fleetms.Scope.has_any_permission?(@current_scope, [
                :view_parts,
                :view_inventory_locations
              ])
            }
            id="dropdown-inventory"
            icon="fa-warehouse"
            label={gettext("Inventory")}
          >
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_parts)}
              icon="fa-box"
              label={gettext("Parts")}
              navigate={~p"/o/#{@current_scope.organization}/parts"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_inventory_locations)}
              icon="fa-location-dot"
              label={gettext("Inventory Locations")}
              navigate={~p"/o/#{@current_scope.organization}/inventory-locations"}
            />
          </.nav_group>

          <.nav_link
            :if={Fleetms.Scope.has_permission?(@current_scope, :view_fuel_entries)}
            icon="fa-gas-pump"
            label={gettext("Fuel Tracking")}
            navigate={~p"/o/#{@current_scope.organization}/fuel"}
          />
          <.nav_link
            :if={Fleetms.Scope.has_permission?(@current_scope, :view_expenses)}
            icon="fa-receipt"
            label={gettext("Expenses")}
            navigate={~p"/o/#{@current_scope.organization}/expenses"}
          />
          <.nav_link
            :if={Fleetms.Scope.has_permission?(@current_scope, :view_contacts)}
            icon="fa-address-book"
            label={gettext("Contacts")}
            navigate={~p"/o/#{@current_scope.organization}/contacts"}
          />
          <.nav_link
            icon="fa-chart-area"
            label={gettext("Reports")}
            navigate={~p"/o/#{@current_scope.organization}/reports"}
          />
          <.nav_link
            :if={Fleetms.Scope.owner?(@current_scope)}
            icon="fa-credit-card"
            label={gettext("Billing")}
            navigate={~p"/o/#{@current_scope.organization}/billing"}
          />

          <.nav_group
            :if={
              not Fleetms.Scope.individual?(@current_scope) and
                Fleetms.Scope.has_any_permission?(@current_scope, [
                  :view_users,
                  :view_roles,
                  :view_user_roles,
                  :view_tags
                ])
            }
            id="dropdown-administration"
            icon="fa-users-gear"
            label={gettext("Administration")}
          >
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_users)}
              icon="fa-user"
              label={gettext("Users")}
              navigate={~p"/o/#{@current_scope.organization}/users"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_roles)}
              icon="fa-user-shield"
              label={gettext("Roles & Permissions")}
              navigate={~p"/o/#{@current_scope.organization}/roles"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_user_roles)}
              icon="fa-user-tag"
              label={gettext("User Roles")}
              navigate={~p"/o/#{@current_scope.organization}/user-roles"}
            />
            <.nav_subitem
              :if={Fleetms.Scope.has_permission?(@current_scope, :view_tags)}
              icon="fa-tags"
              label={gettext("Tags")}
              navigate={~p"/o/#{@current_scope.organization}/tags"}
            />
          </.nav_group>
        </ul>

        <ul class="my-5 space-y-2 border-t border-gray-200 pt-5 dark:border-gray-700">
          <.nav_link
            :if={Fleetms.Scope.has_permission?(@current_scope, :manage_users)}
            icon="fa-user-plus"
            label={gettext("Invite people")}
            navigate={~p"/o/#{@current_scope.organization}/users/new"}
          />
          <.nav_link
            icon="fa-book"
            label={gettext("Documentation")}
            href="https://hexdocs.pm/phoenix/overview.html"
            target="_blank"
          />
          <.nav_link
            icon="fa-brands fa-github"
            label="GitHub"
            href="https://github.com/jmnda-dev/fleetms"
            target="_blank"
          />
        </ul>
      </div>
    </aside>
    """
  end

  @doc false
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :rest, :global, include: ~w(href navigate target)

  defp nav_link(assigns) do
    ~H"""
    <li>
      <.link
        {@rest}
        data-nav-link
        class={[
          "group flex h-10 w-full items-center rounded-lg p-2 text-base font-medium text-gray-900 hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700",
          @active && "bg-gray-100 dark:bg-gray-700"
        ]}
      >
        <i class={[
          "w-6 shrink-0 text-center text-gray-400 group-hover:text-gray-900 dark:group-hover:text-white",
          icon_class(@icon)
        ]}>
        </i>
        <span class="ml-3 whitespace-nowrap" data-sidebar-collapse-hide>{@label}</span>
      </.link>
    </li>
    """
  end

  @doc false
  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp nav_group(assigns) do
    ~H"""
    <li>
      <button
        type="button"
        class="group flex h-10 w-full items-center rounded-lg p-2 text-base font-medium text-gray-900 hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700"
        aria-controls={@id}
        aria-expanded="false"
        data-nav-collapse={@id}
      >
        <i class={[
          "w-6 shrink-0 text-center text-gray-400 group-hover:text-gray-900 dark:group-hover:text-white",
          icon_class(@icon)
        ]}>
        </i>
        <span class="ml-3 flex-1 whitespace-nowrap text-left" data-sidebar-collapse-hide>
          {@label}
        </span>
        <i class="fa-solid fa-chevron-down text-xs" data-sidebar-collapse-hide></i>
      </button>
      <%!-- The menu is NOT wrapped in `data-sidebar-collapse-hide`: when the sidebar is
           collapsed, layout.js force-shows every menu so the sub-item icons stay
           reachable. When expanded, layout.js applies each group's open/closed state. --%>
      <ul id={@id} data-nav-menu class="hidden space-y-2 py-2">
        {render_slot(@inner_block)}
      </ul>
    </li>
    """
  end

  @doc false
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :rest, :global, include: ~w(href navigate target)

  defp nav_subitem(assigns) do
    ~H"""
    <li>
      <.link
        {@rest}
        data-nav-link
        data-sidebar-collapse-subitem
        class="group flex w-full items-center rounded-lg p-2 pl-10 text-base font-medium text-gray-900 hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700"
      >
        <i class={[
          "w-6 shrink-0 text-center text-gray-400 group-hover:text-gray-900 dark:group-hover:text-white",
          icon_class(@icon)
        ]}>
        </i>
        <span class="ml-3 whitespace-nowrap" data-sidebar-collapse-hide>{@label}</span>
      </.link>
    </li>
    """
  end

  # FontAwesome `fa-brands` icons set their own family prefix; everything else
  # defaults to the solid family.
  defp icon_class("fa-brands " <> _ = icon), do: icon
  defp icon_class(icon), do: "fa-solid " <> icon

  defp user_label(%{user: %{email: email}}) when is_binary(email), do: email
  defp user_label(_), do: gettext("Account")

  defp user_email(%{user: %{email: email}}) when is_binary(email), do: email
  defp user_email(_), do: ""

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="fa-arrow-rotate-right" class="ml-1 fa-spin text-xs" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="fa-arrow-rotate-right" class="ml-1 fa-spin text-xs" />
      </.flash>
    </div>
    """
  end
end
