defmodule FleetmsWeb.BillingLive do
  @moduledoc """
  The organization's billing page (owner only): the current subscription and
  entitlement, the plan catalogue to subscribe to, and the invoice history — with a
  pay flow that either redirects to the provider's hosted checkout (DPO) or shows
  pay-in instructions (Lenco).
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Billing
  alias Fleetms.Billing.Checkout
  alias Fleetms.Scope

  @provider_labels %{
    dpo: "Card or mobile money",
    lenco: "Bank or mobile money transfer"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Billing"), active_link: :billing, pending: nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope

    if Scope.owner?(scope) do
      {:noreply, load_billing(socket)}
    else
      {:noreply,
       socket
       |> put_flash(:error, gettext("Only the organization owner can manage billing."))
       |> push_navigate(to: ~p"/o/#{scope.organization}")}
    end
  end

  defp load_billing(socket) do
    org = socket.assigns.current_scope.organization

    subscription =
      org.id
      |> Billing.list_organization_subscriptions!(authorize?: false, load: [:plan, :active_now?])
      |> List.first()

    invoices = Billing.list_organization_invoices!(org.id, authorize?: false)
    plans = Billing.list_active_plans!(authorize?: false)
    providers = available_providers()

    socket
    |> assign(:subscription, subscription)
    |> assign(:invoices, invoices)
    |> assign(:open_invoices, Enum.filter(invoices, &(&1.status == :open)))
    |> assign(:plans, plans)
    |> assign(:providers, providers)
    |> assign(:selected_provider, socket.assigns[:selected_provider] || List.first(providers))
    |> assign(:can_subscribe?, can_subscribe?(subscription))
  end

  @impl true
  def handle_event("select_provider", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, :selected_provider, String.to_existing_atom(provider))}
  end

  def handle_event("subscribe", %{"plan_id" => plan_id} = params, socket) do
    scope = socket.assigns.current_scope
    quantity = parse_quantity(params["quantity"])
    provider = socket.assigns.selected_provider

    case provider &&
           Checkout.subscribe_and_pay(scope.organization, plan_id, quantity, provider, scope.user) do
      {:ok, %{payment: payment}} ->
        handoff(socket, payment)

      nil ->
        {:noreply, put_flash(socket, :error, gettext("No online payment method is set up yet."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  def handle_event("pay_invoice", %{"invoice_id" => invoice_id}, socket) do
    scope = socket.assigns.current_scope
    provider = socket.assigns.selected_provider
    invoice = Billing.get_invoice!(invoice_id, authorize?: false)

    case provider && Checkout.pay_invoice(invoice, provider, scope.user) do
      {:ok, payment} ->
        handoff(socket, payment)

      nil ->
        {:noreply, put_flash(socket, :error, gettext("No online payment method is set up yet."))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  def handle_event("refresh", _params, socket),
    do: {:noreply, load_billing(assign(socket, :pending, nil))}

  # Redirect to a hosted checkout (DPO), or show pay-in instructions (Lenco).
  defp handoff(socket, %{checkout_url: url}) when is_binary(url) do
    {:noreply, redirect(socket, external: url)}
  end

  defp handoff(socket, %{instructions: instructions}) when is_map(instructions) do
    {:noreply,
     socket
     |> assign(:pending, instructions)
     |> put_flash(
       :info,
       gettext("Transfer the amount using the details below to complete payment.")
     )
     |> load_billing()}
  end

  defp handoff(socket, _payment) do
    {:noreply,
     put_flash(socket, :error, gettext("Couldn't start the payment. Please try again."))}
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
        %{label: gettext("Billing")}
      ]} />

      <.header>
        {gettext("Billing")}
        <:subtitle>{gettext("Your subscription, plans and invoices.")}</:subtitle>
      </.header>

      <div class="mt-6 max-w-4xl space-y-6">
        <.subscription_card subscription={@subscription} />

        <.pending_instructions :if={@pending} instructions={@pending} />

        <.provider_picker
          :if={length(@providers) > 1}
          providers={@providers}
          selected={@selected_provider}
        />

        <section :if={@can_subscribe?} id="plans">
          <h2 class="mb-3 text-lg font-semibold text-heading">{gettext("Choose a plan")}</h2>
          <p :if={@providers == []} class="mb-3 text-sm text-body">
            {gettext("Online payment isn't set up yet — contact us to be invoiced.")}
          </p>
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <.plan_card
              :for={plan <- @plans}
              plan={plan}
              disabled={@providers == []}
            />
          </div>
        </section>

        <.invoices_table invoices={@invoices} payable={@providers != []} />
      </div>
    </Layouts.app>
    """
  end

  # --- components ---

  defp subscription_card(%{subscription: nil} = assigns) do
    ~H"""
    <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
      <p class="text-body">
        {gettext("You don't have a subscription yet. Choose a plan below to get started.")}
      </p>
    </section>
    """
  end

  defp subscription_card(assigns) do
    ~H"""
    <section class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p class="text-sm text-body">{gettext("Current plan")}</p>
          <p class="text-lg font-semibold text-heading">{@subscription.plan.name}</p>
        </div>
        <.status_badge status={@subscription.status} />
      </div>
      <dl class="mt-4 grid grid-cols-1 gap-3 text-sm sm:grid-cols-3">
        <div>
          <dt class="text-body">{gettext("Vehicles")}</dt>
          <dd class="text-heading">{@subscription.quantity}</dd>
        </div>
        <div>
          <dt class="text-body">{gettext("Renews / ends")}</dt>
          <dd class="text-heading">{format_datetime(@subscription.current_period_end)}</dd>
        </div>
        <div>
          <dt class="text-body">{gettext("Entitled")}</dt>
          <dd class="text-heading">
            {if @subscription.active_now?, do: gettext("Yes"), else: gettext("No")}
          </dd>
        </div>
      </dl>
    </section>
    """
  end

  defp plan_card(assigns) do
    ~H"""
    <div class="flex flex-col rounded-base border border-default bg-white p-5 shadow-sm dark:bg-gray-800">
      <h3 class="text-base font-semibold text-heading">{@plan.name}</h3>
      <p class="mt-1 text-sm text-body">{@plan.description}</p>
      <p class="mt-3 text-2xl font-bold text-heading">
        {Money.to_string!(@plan.price)}
        <span class="text-sm font-normal text-body">/ {@plan.interval}</span>
      </p>
      <p :if={@plan.price_per_vehicle} class="text-xs text-body">
        {gettext("+ %{amount} per extra vehicle", amount: Money.to_string!(@plan.price_per_vehicle))}
      </p>

      <.form
        :let={f}
        for={to_form(%{"plan_id" => @plan.id, "quantity" => "1"}, as: :subscribe)}
        phx-submit="subscribe"
        class="mt-4 space-y-3"
      >
        <input type="hidden" name="plan_id" value={@plan.id} />
        <.input field={f[:quantity]} type="number" label={gettext("Vehicles")} min="1" value="1" />
        <.button
          type="submit"
          class="w-full"
          disabled={@disabled}
          phx-disable-with={gettext("Starting…")}
        >
          {gettext("Subscribe")}
        </.button>
      </.form>
    </div>
    """
  end

  defp provider_picker(assigns) do
    ~H"""
    <section class="rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800">
      <p class="mb-2 text-sm font-medium text-heading">{gettext("Payment method")}</p>
      <div class="flex flex-wrap gap-2">
        <button
          :for={provider <- @providers}
          type="button"
          phx-click="select_provider"
          phx-value-provider={provider}
          class={[
            "rounded-base border px-3 py-2 text-sm",
            if(provider == @selected,
              do: "border-primary-700 bg-primary-50 text-primary-700 dark:bg-gray-700",
              else: "border-default text-body"
            )
          ]}
        >
          {provider_label(provider)}
        </button>
      </div>
    </section>
    """
  end

  defp pending_instructions(assigns) do
    ~H"""
    <section class="rounded-base border border-amber-300 bg-amber-50 p-6 dark:border-amber-800 dark:bg-gray-800">
      <h2 class="text-base font-semibold text-heading">{gettext("Complete your transfer")}</h2>
      <dl class="mt-3 grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
        <div :if={@instructions["bank_name"]}>
          <dt class="text-body">{gettext("Bank")}</dt>
          <dd class="font-medium text-heading">{@instructions["bank_name"]}</dd>
        </div>
        <div :if={@instructions["account_number"]}>
          <dt class="text-body">{gettext("Account number")}</dt>
          <dd class="font-mono font-medium text-heading">{@instructions["account_number"]}</dd>
        </div>
        <div :if={@instructions["account_name"]}>
          <dt class="text-body">{gettext("Account name")}</dt>
          <dd class="font-medium text-heading">{@instructions["account_name"]}</dd>
        </div>
      </dl>
      <p class="mt-3 text-xs text-body">
        {gettext("Payment confirms automatically once the transfer is received.")}
      </p>
      <.button type="button" phx-click="refresh" class="mt-3">{gettext("Refresh status")}</.button>
    </section>
    """
  end

  defp invoices_table(%{invoices: []} = assigns) do
    ~H"""
    <section>
      <h2 class="mb-3 text-lg font-semibold text-heading">{gettext("Invoices")}</h2>
      <p class="text-sm text-body">{gettext("No invoices yet.")}</p>
    </section>
    """
  end

  defp invoices_table(assigns) do
    ~H"""
    <section>
      <h2 class="mb-3 text-lg font-semibold text-heading">{gettext("Invoices")}</h2>
      <div class="overflow-hidden rounded-base border border-default bg-white shadow-sm dark:bg-gray-800">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-default text-body">
            <tr>
              <th class="px-4 py-3 font-medium">{gettext("Number")}</th>
              <th class="px-4 py-3 font-medium">{gettext("Amount")}</th>
              <th class="px-4 py-3 font-medium">{gettext("Status")}</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-default">
            <tr :for={invoice <- @invoices}>
              <td class="px-4 py-3 text-heading">{invoice.number}</td>
              <td class="px-4 py-3 text-heading">{Money.to_string!(invoice.amount_due)}</td>
              <td class="px-4 py-3"><.invoice_badge status={invoice.status} /></td>
              <td class="px-4 py-3 text-right">
                <.button
                  :if={invoice.status == :open and @payable}
                  type="button"
                  phx-click="pay_invoice"
                  phx-value-invoice_id={invoice.id}
                  class="!py-1.5 !text-xs"
                >
                  {gettext("Pay now")}
                </.button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={["rounded-full px-2.5 py-1 text-xs font-medium", sub_badge_class(@status)]}>
      {@status |> to_string() |> String.replace("_", " ")}
    </span>
    """
  end

  defp invoice_badge(assigns) do
    ~H"""
    <span class={["rounded-full px-2.5 py-1 text-xs font-medium", invoice_badge_class(@status)]}>
      {@status}
    </span>
    """
  end

  # --- helpers ---

  defp provider_label(provider), do: Map.get(@provider_labels, provider, to_string(provider))

  defp available_providers do
    cfg = Application.get_env(:fleetms, Fleetms.Billing, [])

    [dpo: cfg[:dpo][:company_token], lenco: cfg[:lenco][:api_token]]
    |> Enum.filter(fn {_provider, token} -> is_binary(token) and token != "" end)
    |> Enum.map(&elem(&1, 0))
  end

  defp can_subscribe?(nil), do: true

  defp can_subscribe?(%{status: status}),
    do: status in [:incomplete, :past_due, :canceled, :expired]

  defp parse_quantity(value) do
    case Integer.parse(to_string(value || "1")) do
      {quantity, _} when quantity >= 1 -> quantity
      _ -> 1
    end
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")

  defp error_message(:forbidden), do: gettext("You don't have permission to do that.")

  defp error_message(_),
    do: gettext("Something went wrong starting the payment. Please try again.")

  defp sub_badge_class(status) when status in [:active, :trialing],
    do: "bg-emerald-50 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300"

  defp sub_badge_class(:past_due),
    do: "bg-amber-50 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300"

  defp sub_badge_class(_),
    do: "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300"

  defp invoice_badge_class(:paid),
    do: "bg-emerald-50 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300"

  defp invoice_badge_class(:open),
    do: "bg-amber-50 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300"

  defp invoice_badge_class(_),
    do: "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300"
end
