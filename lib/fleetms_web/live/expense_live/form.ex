defmodule FleetmsWeb.ExpenseLive.Form do
  @moduledoc """
  Create / edit a vehicle expense.

  An `AshPhoenix.Form` over the expense's create/update action. The amount is a
  `Money` value, rendered as a paired amount + currency control (named
  `expense[amount][amount]` / `expense[amount][currency]`), which AshMoney casts.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Expenses
  alias Fleetms.Expenses.Expense
  alias Fleetms.Expenses.ExpenseCategory
  alias Fleetms.Format
  alias Fleetms.Maintenance
  alias Fleetms.VehicleManagement

  @currencies ~w(USD EUR GBP ZMW ZAR KES NGN GHS TZS UGX RWF INR JPY CNY CAD AUD)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :expenses, currencies: @currencies)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Expense, :create, domain: Expenses, as: "expense", scope: scope)

    socket
    |> assign(page_title: gettext("New expense"), preselect_vehicle: params["vehicle_id"])
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Expenses.get_expense(id, scope: scope) do
      {:ok, expense} ->
        form = Form.for_update(expense, :update, domain: Expenses, as: "expense", scope: scope)

        socket
        |> assign(page_title: gettext("Edit expense"), preselect_vehicle: nil)
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That expense could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/expenses")
    end
  end

  defp assign_lookups(socket, scope) do
    assign(socket, vehicles: vehicle_options(scope), vendors: vendor_options(scope))
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
        %{label: gettext("Expenses"), path: ~p"/o/#{org(assigns)}/expenses"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>{gettext("A vehicle cost that isn't fuel or a work order.")}</:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="expense-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <.search_select
              field={f[:vehicle_id]}
              value={f[:vehicle_id].value || @preselect_vehicle}
              label={gettext("Vehicle")}
              prompt={gettext("Select a vehicle")}
              options={@vehicles}
            />
            <.input field={f[:expense_date]} type="date" label={gettext("Date")} required />

            <.input
              field={f[:category]}
              type="select"
              label={gettext("Category")}
              options={category_options()}
            />
            <.money_field
              field={f[:amount]}
              label={gettext("Amount")}
              currencies={@currencies}
              default_currency={Format.default_currency(org(assigns))}
            />

            <.search_select
              field={f[:vendor_id]}
              label={gettext("Vendor")}
              prompt={gettext("Optional")}
              options={@vendors}
            />
            <.input
              field={f[:odometer]}
              value={Format.distance_input(f[:odometer].value, org(assigns))}
              type="number"
              step="0.01"
              label={"#{gettext("Odometer")} (#{Format.distance_unit(org(assigns))})"}
            />

            <div class="md:col-span-2">
              <.input field={f[:description]} type="textarea" label={gettext("Description")} />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save expense")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/expenses"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :currencies, :list, required: true
  attr :default_currency, :string, required: true

  defp money_field(assigns) do
    errors =
      if Phoenix.Component.used_input?(assigns.field),
        do: Enum.map(assigns.field.errors, &translate_error/1),
        else: []

    currencies =
      if assigns.default_currency in assigns.currencies,
        do: assigns.currencies,
        else: [assigns.default_currency | assigns.currencies]

    assigns = assign(assigns, errors: errors, currencies: currencies)

    ~H"""
    <div class="mb-4">
      <label for={@field.id <> "_amount"} class="mb-2 block text-sm font-medium text-heading">
        {@label}
      </label>
      <div class="flex gap-2">
        <input
          type="number"
          step="0.01"
          min="0"
          id={@field.id <> "_amount"}
          name={@field.name <> "[amount]"}
          value={money_amount(@field.value)}
          placeholder="0.00"
          class={[
            "block w-full rounded-base border bg-neutral-secondary-medium px-3 py-2.5 text-sm text-heading shadow-xs focus:border-brand focus:ring-brand",
            @errors == [] && "border-default-medium",
            @errors != [] && "border-danger focus:border-danger focus:ring-danger"
          ]}
        />
        <select
          id={@field.id <> "_currency"}
          aria-label={gettext("Currency")}
          name={@field.name <> "[currency]"}
          class="block w-28 shrink-0 rounded-base border border-default-medium bg-neutral-secondary-medium px-2 py-2.5 text-sm text-heading shadow-xs focus:border-brand focus:ring-brand"
        >
          {Phoenix.HTML.Form.options_for_select(
            @currencies,
            money_currency(@field.value, @default_currency)
          )}
        </select>
      </div>
      <p :for={msg <- @errors} class="mt-1.5 flex items-center gap-1 text-sm text-fg-danger">
        <.icon name="fa-circle-exclamation" class="text-xs" />
        {msg}
      </p>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"expense" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"expense" => params}, socket) do
    params = canonical_odometer(params, socket)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _expense} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Expense saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/expenses")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  # Odometer is entered in the org's distance unit and stored canonically in km.
  defp canonical_odometer(%{"odometer" => value} = params, socket) when value not in [nil, ""] do
    Map.put(params, "odometer", Format.to_canonical_distance(value, org(socket)))
  end

  defp canonical_odometer(params, _socket), do: params

  defp category_options do
    Enum.map(ExpenseCategory.values(), fn c ->
      {c |> to_string() |> String.replace("_", " ") |> String.capitalize(), c}
    end)
  end

  defp vehicle_options(scope) do
    case VehicleManagement.list_vehicles(%{sort_by: :name, sort_order: :asc},
           scope: scope,
           page: [limit: 1000]
         ) do
      {:ok, %{results: vehicles}} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp vendor_options(scope) do
    case Maintenance.list_vendors(%{}, scope: scope) do
      {:ok, %{results: vendors}} -> Enum.map(vendors, &{&1.name, &1.id})
      {:ok, vendors} when is_list(vendors) -> Enum.map(vendors, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp money_amount(%Money{amount: amount}), do: Decimal.to_string(amount)
  defp money_amount(_), do: nil

  defp money_currency(%Money{currency: currency}, _default), do: to_string(currency)
  defp money_currency(_, default), do: default

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
