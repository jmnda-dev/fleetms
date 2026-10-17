defmodule FleetmsWeb.AdminLive.OrganizationShow do
  @moduledoc """
  Platform admin: the detail page for one client organization.

  The hub for operating a single tenant — its lifecycle status, key usage figures,
  members, display settings, KYC (client profile), and the staff-access history —
  plus the lifecycle actions (suspend / reactivate) and a way to enter the org as
  staff. Tenant-less and staff-only (`is_super_admin`); all reads use the
  super-admin bypass.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    case Accounts.get_organization(id,
           actor: user,
           load: [:member_count, :client_profile, user_organizations: [user: [:profile]]]
         ) do
      {:ok, org} ->
        {:ok,
         socket
         |> assign(page_title: org.name, org: org)
         |> assign(stats: Fleetms.PlatformStats.for_organization(org))
         |> assign(access_log: recent_access(user, org))
         |> assign(show_suspend: false)
         |> load_billing(org.id)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("That organization could not be found."))
         |> push_navigate(to: ~p"/admin/organizations")}
    end
  end

  defp recent_access(user, org) do
    Accounts.list_platform_access_logs!(%{organization_id: org.id},
      actor: user,
      page: [limit: 10]
    ).results
  end

  defp load_billing(socket, org_id) do
    subscription =
      org_id
      |> Fleetms.Billing.list_organization_subscriptions!(authorize?: false, load: [:plan])
      |> List.first()

    invoices = Fleetms.Billing.list_organization_invoices!(org_id, authorize?: false)
    assign(socket, subscription: subscription, invoices: invoices)
  end

  @impl true
  def handle_event("toggle-suspend-form", _params, socket) do
    {:noreply, assign(socket, show_suspend: !socket.assigns.show_suspend)}
  end

  def handle_event("mark-invoice-paid", %{"invoice_id" => invoice_id}, socket) do
    user = socket.assigns.current_user
    invoice = Fleetms.Billing.get_invoice!(invoice_id, authorize?: false)

    case Fleetms.Billing.Checkout.mark_invoice_paid_manually(invoice, user) do
      {:ok, _payment} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Invoice %{number} marked as paid.", number: invoice.number))
         |> load_billing(socket.assigns.org.id)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Couldn't mark the invoice paid."))}
    end
  end

  def handle_event("suspend", params, socket) do
    user = socket.assigns.current_user
    reason = params["reason"]

    case Accounts.suspend_organization(socket.assigns.org, %{suspension_reason: reason},
           actor: user
         ) do
      {:ok, org} ->
        {:noreply,
         socket
         |> assign(org: reload(user, org.id), show_suspend: false)
         |> put_flash(
           :info,
           gettext("Organization suspended. Its members can no longer sign in.")
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not suspend the organization."))}
    end
  end

  def handle_event("reactivate", _params, socket) do
    user = socket.assigns.current_user

    case Accounts.reactivate_organization(socket.assigns.org, %{}, actor: user) do
      {:ok, org} ->
        {:noreply,
         socket
         |> assign(org: reload(user, org.id))
         |> put_flash(:info, gettext("Organization reactivated."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not reactivate the organization."))}
    end
  end

  def handle_event("enter", _params, socket) do
    org = socket.assigns.org
    record_access(socket.assigns.current_user, org)
    {:noreply, push_navigate(socket, to: ~p"/o/#{org}")}
  end

  defp reload(user, id) do
    Accounts.get_organization!(id,
      actor: user,
      load: [:member_count, :client_profile, user_organizations: [user: [:profile]]]
    )
  end

  defp record_access(user, org) do
    Accounts.record_platform_access(%{organization_id: org.id}, actor: user)
  rescue
    _ -> :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin_shell active={:organizations}>
      <Layouts.flash_group flash={@flash} />

      <.breadcrumbs items={[
        %{label: gettext("Organizations"), path: ~p"/admin/organizations"},
        %{label: @org.name}
      ]} />

      <.header>
        <span class="inline-flex items-center gap-3">
          {@org.name} <.status_badge status={@org.status} />
        </span>
        <:subtitle>
          {Phoenix.Naming.humanize(@org.account_type)} · {gettext("joined %{date}",
            date: Calendar.strftime(@org.inserted_at, "%Y-%m-%d")
          )} · <span class="font-mono text-xs">{@org.public_id}</span>
        </:subtitle>
        <:actions>
          <.button variant="secondary" phx-click="enter">
            <.icon name="fa-right-to-bracket" class="me-1 text-xs" /> {gettext("Enter as staff")}
          </.button>
          <.button
            :if={@org.status == :active}
            variant="danger"
            phx-click="toggle-suspend-form"
          >
            <.icon name="fa-ban" class="me-1 text-xs" /> {gettext("Suspend")}
          </.button>
          <.button
            :if={@org.status == :suspended}
            variant="success"
            phx-click="reactivate"
            data-confirm={gettext("Reactivate this organization? Members will regain access.")}
          >
            <.icon name="fa-circle-check" class="me-1 text-xs" /> {gettext("Reactivate")}
          </.button>
        </:actions>
      </.header>

      <div
        :if={@org.status == :suspended}
        class="mt-4 rounded-base border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-900/30 dark:text-amber-200"
      >
        <.icon name="fa-ban" class="me-1" />
        {gettext("Suspended %{when}.",
          when: @org.suspended_at && Calendar.strftime(@org.suspended_at, "%Y-%m-%d %H:%M")
        )}
        <span :if={present?(@org.suspension_reason)}>— {@org.suspension_reason}</span>
      </div>

      <form
        :if={@show_suspend and @org.status == :active}
        phx-submit="suspend"
        class="mt-4 rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800"
      >
        <label class="mb-2 block text-sm font-medium text-heading">
          {gettext("Reason for suspension (internal)")}
        </label>
        <input
          type="text"
          name="reason"
          placeholder={gettext("e.g. Non-payment — invoice #123 overdue")}
          class="block w-full rounded-base border border-default-medium bg-neutral-secondary-medium p-2 text-sm text-heading focus:border-brand focus:ring-brand"
        />
        <div class="mt-3 flex gap-2">
          <.button type="submit" variant="danger" size="sm">{gettext("Confirm suspension")}</.button>
          <.button type="button" variant="secondary" size="sm" phx-click="toggle-suspend-form">
            {gettext("Cancel")}
          </.button>
        </div>
      </form>

      <div class="mt-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <.mini_stat label={gettext("Members")} value={@org.member_count} icon="fa-users" />
        <.mini_stat label={gettext("Vehicles")} value={@stats.vehicles} icon="fa-truck" />
        <.mini_stat
          label={gettext("Open issues")}
          value={@stats.open_issues}
          icon="fa-triangle-exclamation"
        />
        <.mini_stat
          label={gettext("Open work orders")}
          value={@stats.open_work_orders}
          icon="fa-screwdriver-wrench"
        />
      </div>

      <div class="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <%!-- Members --%>
        <.panel title={gettext("Members")}>
          <ul class="divide-y divide-default">
            <li
              :for={m <- @org.user_organizations}
              class="flex items-center justify-between px-4 py-2.5 text-sm"
            >
              <span class="min-w-0">
                <span class="block truncate font-medium text-heading">{member_name(m)}</span>
              </span>
              <span class="flex items-center gap-2">
                <span
                  :if={m.owner?}
                  class="rounded bg-purple-100 px-1.5 py-0.5 text-xs font-medium text-purple-800 dark:bg-purple-900 dark:text-purple-300"
                >
                  {gettext("Owner")}
                </span>
                <span class="text-xs text-body">{Phoenix.Naming.humanize(m.status)}</span>
              </span>
            </li>
            <li :if={@org.user_organizations == []} class="px-4 py-6 text-center text-sm text-body">
              {gettext("No members.")}
            </li>
          </ul>
        </.panel>

        <%!-- Settings + KYC --%>
        <.panel title={gettext("Details")}>
          <dl class="divide-y divide-default text-sm">
            <.detail_row label={gettext("Currency")} value={@org.currency} />
            <.detail_row label={gettext("Units")} value={Phoenix.Naming.humanize(@org.unit_system)} />
            <.detail_row label={gettext("Timezone")} value={@org.timezone} />
            <%= if @org.client_profile do %>
              <.detail_row label={gettext("Contact")} value={@org.client_profile.contact_name} />
              <.detail_row label={gettext("Contact email")} value={@org.client_profile.contact_email} />
              <.detail_row label={gettext("Contact phone")} value={@org.client_profile.contact_phone} />
              <.detail_row label={gettext("Reg. number")} value={@org.client_profile.reg_number} />
              <.detail_row
                label={gettext("KYC status")}
                value={
                  @org.client_profile.status && Phoenix.Naming.humanize(@org.client_profile.status)
                }
              />
            <% end %>
          </dl>
        </.panel>
      </div>

      <%!-- Staff access history --%>
      <.panel title={gettext("Staff access history")} class="mt-6">
        <ul class="divide-y divide-default">
          <li
            :for={entry <- @access_log}
            class="flex items-center justify-between px-4 py-2.5 text-sm"
          >
            <span class="text-heading">{entry.admin_user && to_string(entry.admin_user.email)}</span>
            <span class="text-xs text-body">
              {Calendar.strftime(entry.inserted_at, "%Y-%m-%d %H:%M")}
            </span>
          </li>
          <li :if={@access_log == []} class="px-4 py-6 text-center text-sm text-body">
            {gettext("No staff has entered this organization.")}
          </li>
        </ul>
      </.panel>

      <.panel title={gettext("Billing")} class="mt-6">
        <div class="px-4 py-3 text-sm">
          <p :if={is_nil(@subscription)} class="text-body">{gettext("No subscription.")}</p>
          <div :if={@subscription} class="flex flex-wrap items-center gap-2">
            <span class="font-medium text-heading">{@subscription.plan.name}</span>
            <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-600 dark:bg-gray-700 dark:text-gray-300">
              {@subscription.status |> to_string() |> String.replace("_", " ")}
            </span>
            <span :if={@subscription.current_period_end} class="text-xs text-body">
              {gettext("until %{date}",
                date: Calendar.strftime(@subscription.current_period_end, "%Y-%m-%d")
              )}
            </span>
          </div>
        </div>

        <table :if={@invoices != []} class="w-full text-left text-sm">
          <thead class="border-y border-default text-body">
            <tr>
              <th class="px-4 py-2 font-medium">{gettext("Invoice")}</th>
              <th class="px-4 py-2 font-medium">{gettext("Amount")}</th>
              <th class="px-4 py-2 font-medium">{gettext("Status")}</th>
              <th class="px-4 py-2"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-default">
            <tr :for={invoice <- @invoices}>
              <td class="px-4 py-2 text-heading">{invoice.number}</td>
              <td class="px-4 py-2 text-heading">{Money.to_string!(invoice.amount_due)}</td>
              <td class="px-4 py-2 text-body">{invoice.status}</td>
              <td class="px-4 py-2 text-right">
                <button
                  :if={invoice.status == :open}
                  type="button"
                  phx-click="mark-invoice-paid"
                  phx-value-invoice_id={invoice.id}
                  data-confirm={gettext("Mark this invoice as paid (offline settlement)?")}
                  class="rounded-base bg-primary-700 px-3 py-1 text-xs font-semibold text-white hover:bg-primary-800"
                >
                  {gettext("Mark paid")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <p :if={@invoices == []} class="px-4 py-3 text-sm text-body">{gettext("No invoices.")}</p>
      </.panel>
    </Layouts.admin_shell>
    """
  end

  # --- small presentational components ---

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded-full px-2.5 py-0.5 text-xs font-semibold",
      @status == :active && "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
      @status == :suspended && "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"
    ]}>
      {Phoenix.Naming.humanize(@status)}
    </span>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true

  defp mini_stat(assigns) do
    ~H"""
    <div class="rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800">
      <div class="flex items-center justify-between">
        <p class="text-xs font-medium text-body">{@label}</p>
        <.icon name={@icon} class="text-body text-sm" />
      </div>
      <p class="mt-1 text-2xl font-bold text-heading">{@value}</p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  defp panel(assigns) do
    ~H"""
    <div class={["rounded-base border border-default bg-white shadow-sm dark:bg-gray-800", @class]}>
      <div class="border-b border-default px-4 py-3">
        <h2 class="text-sm font-semibold text-heading">{@title}</h2>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, default: nil

  defp detail_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between px-4 py-2.5">
      <dt class="text-body">{@label}</dt>
      <dd class="font-medium text-heading">{present(@value)}</dd>
    </div>
    """
  end

  defp member_name(%{user: %{profile: %{first_name: f, last_name: l}}})
       when is_binary(f) or is_binary(l) do
    [f, l] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")
  end

  defp member_name(%{user: %{email: email}}) when not is_nil(email), do: to_string(email)
  defp member_name(_), do: gettext("Unknown")

  defp present(v) when v in [nil, ""], do: "—"
  defp present(v), do: v

  defp present?(v), do: v not in [nil, ""]
end
