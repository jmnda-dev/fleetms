defmodule FleetmsWeb.OrgLive.Index do
  @moduledoc """
  Organization picker (workspace launcher). Lists the organizations the signed-in
  user belongs to; choosing one navigates into its tenant-scoped app. Renders
  without the dashboard shell — no tenant context yet.
  """
  use FleetmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    memberships =
      user
      |> Ash.load!([user_organizations: [organization: [:member_count]]], actor: user)
      |> Map.get(:user_organizations)

    {:ok, assign(socket, :memberships, memberships)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.org_shell current_user={@current_user}>
      <Layouts.flash_group flash={@flash} />

      <div class="mx-auto w-full max-w-3xl">
        <div
          :if={@current_user.is_super_admin}
          class="mb-8 flex flex-col gap-3 rounded-lg border border-brand-subtle bg-brand-softer p-5 sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex items-start gap-3">
            <i class="fa-solid fa-shield-halved mt-0.5 text-fg-brand-strong"></i>
            <div>
              <p class="text-sm font-semibold text-heading">
                {gettext("You're signed in as platform staff")}
              </p>
              <p class="mt-0.5 text-sm text-body">
                {gettext(
                  "This page is your personal workspaces. To manage clients across the whole platform — provisioning, the individuals pool, feature flags — open the Platform Admin console."
                )}
              </p>
            </div>
          </div>
          <.link
            navigate={~p"/admin"}
            class="inline-flex shrink-0 items-center justify-center gap-1.5 self-start rounded-lg bg-brand px-4 py-2.5 text-sm font-medium text-white hover:bg-brand-strong sm:self-auto dark:text-primary-900"
          >
            {gettext("Open Platform Admin")}
            <i class="fa-solid fa-arrow-right text-xs"></i>
          </.link>
        </div>

        <div class="text-center">
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
            {gettext("Choose an organization")}
          </h1>
          <p class="mt-2 text-sm text-gray-600 dark:text-gray-300">
            {gettext("Pick the organization you want to work in.")}
          </p>
        </div>

        <div :if={@memberships == []} class="mt-8 text-center">
          <p class="text-gray-600 dark:text-gray-300">
            {gettext("You don't belong to any organization yet.")}
          </p>
        </div>

        <div class="mt-8 grid gap-4 sm:grid-cols-2">
          <div
            :for={membership <- @memberships}
            class="flex flex-col rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-700 dark:bg-gray-800"
          >
            <div class="flex items-start justify-between gap-2">
              <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
                {membership.organization.name}
              </h2>
              <span
                :if={membership.owner?}
                class="inline-flex items-center rounded-sm border border-brand-subtle bg-brand-softer px-1.5 py-0.5 text-xs font-medium text-fg-brand-strong"
              >
                {gettext("Owner")}
              </span>
            </div>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              {ngettext(
                "%{count} member",
                "%{count} members",
                membership.organization.member_count
              )}
            </p>
            <.link
              navigate={~p"/o/#{membership.organization}"}
              class="mt-4 inline-flex items-center justify-center self-start rounded-lg bg-brand px-4 py-2.5 text-sm font-medium text-white hover:bg-brand-strong focus:outline-none focus:ring-4 focus:ring-brand-medium dark:text-primary-900"
            >
              {gettext("Open")}
              <i class="fa-solid fa-arrow-right ml-1.5 text-xs"></i>
            </.link>
          </div>

          <.link
            navigate={~p"/orgs/new"}
            class="flex flex-col items-center justify-center rounded-lg border border-dashed border-gray-300 p-6 text-center text-gray-500 hover:border-brand hover:text-fg-brand dark:border-gray-600 dark:text-gray-400"
          >
            <i class="fa-solid fa-plus text-2xl"></i>
            <span class="mt-2 text-sm font-medium">{gettext("Create organization")}</span>
          </.link>
        </div>
      </div>
    </Layouts.org_shell>
    """
  end
end
