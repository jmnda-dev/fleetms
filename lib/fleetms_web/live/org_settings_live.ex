defmodule FleetmsWeb.OrgSettingsLive do
  @moduledoc """
  Organization display settings (owner only): unit system, default currency, timezone
  and date format. Values are stored canonically (metric, UTC) — these only drive how
  amounts and dates are shown and entered across the app.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Accounts
  alias Fleetms.Scope

  @account_types [
    {"Business / corporate", "business"},
    {"Individual (personal fleet)", "individual"}
  ]

  @unit_systems [{"Metric (km, litres)", "metric"}, {"Imperial (miles, gallons)", "imperial"}]

  @date_formats [
    {"2026-08-14 (ISO)", "iso"},
    {"08/14/2026 (US)", "us"},
    {"14/08/2026 (EU)", "eu"},
    {"August 14, 2026 (Long)", "long"}
  ]

  # A curated, readable shortlist — the full IANA database is added with timezone
  # conversion later; this covers the common regions.
  @timezones ~w(
    Etc/UTC
    Africa/Lusaka Africa/Johannesburg Africa/Nairobi Africa/Lagos Africa/Cairo Africa/Accra
    Europe/London Europe/Paris Europe/Berlin Europe/Moscow
    America/New_York America/Chicago America/Denver America/Los_Angeles America/Sao_Paulo
    Asia/Dubai Asia/Kolkata Asia/Shanghai Asia/Tokyo Asia/Singapore
    Australia/Sydney Pacific/Auckland
  )

  # Common currencies, ZMW first (the default).
  @currencies ~w(ZMW USD EUR GBP ZAR KES NGN TZS GHS UGX BWP AUD CAD INR CNY JPY)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Organization Settings"), active_link: :settings)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope

    if Scope.owner?(scope) do
      org = Accounts.get_organization!(scope.organization.id, actor: scope.user)
      {:noreply, socket |> assign(:org, org) |> assign_form(org)}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Only the organization owner can change these settings."))
       |> push_navigate(to: ~p"/o/#{scope.organization}")}
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
        %{label: gettext("Dashboard"), path: ~p"/o/#{@current_scope.organization}", icon: "fa-house"},
        %{label: gettext("Organization Settings")}
      ]} />

      <.header>
        {gettext("Organization Settings")}
        <:subtitle>
          {gettext("How amounts and dates are shown across %{org}.", org: @org.name)}
        </:subtitle>
      </.header>

      <div class="mt-6 max-w-2xl">
        <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <.form
            :let={f}
            for={@form}
            id="org-settings-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={f[:account_type]}
              type="select"
              label={gettext("Account type")}
              options={@account_types}
            />
            <p class="-mt-2 text-xs text-body">
              {gettext("Individual hides members, roles and administration. It changes the UI only.")}
            </p>

            <.input
              field={f[:unit_system]}
              type="select"
              label={gettext("Unit system")}
              options={@unit_systems}
            />
            <p class="-mt-2 text-xs text-body">
              {gettext("Distances and volumes are stored in metric and converted for display.")}
            </p>

            <.input
              field={f[:currency]}
              type="select"
              label={gettext("Default currency")}
              options={@currencies}
            />

            <.input
              field={f[:timezone]}
              type="select"
              label={gettext("Timezone")}
              options={@timezones}
            />

            <.input
              field={f[:date_format]}
              type="select"
              label={gettext("Date format")}
              options={@date_formats}
            />

            <div class="pt-2">
              <.button type="submit" phx-disable-with={gettext("Saving…")}>
                {gettext("Save settings")}
              </.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"settings" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"settings" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, org} ->
        # Reflect the change on the current scope so the rest of the session sees it.
        scope = %{socket.assigns.current_scope | organization: org}

        {:noreply,
         socket
         |> assign(:org, org)
         |> assign(:current_scope, scope)
         |> assign_form(org)
         |> put_flash(:info, gettext("Settings saved."))}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form(socket, org) do
    form =
      AshPhoenix.Form.for_update(org, :update_settings,
        actor: socket.assigns.current_scope.user,
        as: "settings"
      )

    socket
    |> assign(:form, to_form(form))
    |> assign(:account_types, @account_types)
    |> assign(:unit_systems, @unit_systems)
    |> assign(:currencies, @currencies)
    |> assign(:timezones, @timezones)
    |> assign(:date_formats, @date_formats)
  end
end
