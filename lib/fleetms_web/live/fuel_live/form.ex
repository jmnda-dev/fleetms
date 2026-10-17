defmodule FleetmsWeb.FuelLive.Form do
  @moduledoc """
  Create / edit a fuel entry.

  An `AshPhoenix.Form` over the fuel entry's create/update action. The cost is a
  `Money` value, so it renders as a paired amount + currency control whose inputs
  are named `fuel_entry[cost][amount]` / `fuel_entry[cost][currency]`; AshMoney
  casts that nested map straight into a `Money`. Vehicle and "refueled by" are
  searchable selects bound to their writable id attributes; `refueled_at` uses a
  native datetime-local input (a refuel has a time of day).
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Accounts
  alias Fleetms.Format
  alias Fleetms.FuelManagement
  alias Fleetms.Images
  alias Fleetms.Storage
  alias Fleetms.VehicleManagement

  # Unit-bearing inputs shown in the org's units and stored canonically (km / litres).
  @unit_fields %{"odometer" => :distance, "quantity" => :volume}

  # A curated shortlist for the currency picker; the amount is stored with
  # whichever the user picks. Broadened as needed.
  @currencies ~w(USD EUR GBP ZMW ZAR KES NGN GHS TZS UGX RWF INR JPY CNY CAD AUD)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(active_link: :fuel, currencies: @currencies)
     |> allow_upload(:receipt,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(FuelManagement.FuelEntry, :create,
        domain: FuelManagement,
        as: "fuel_entry",
        scope: scope
      )

    socket
    |> assign(page_title: gettext("New fuel entry"), fuel_entry: nil)
    |> assign(preselect_vehicle: params["vehicle_id"])
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case FuelManagement.get_fuel_entry(id, scope: scope) do
      {:ok, fuel_entry} ->
        form =
          Form.for_update(fuel_entry, :update,
            domain: FuelManagement,
            as: "fuel_entry",
            scope: scope
          )

        socket
        |> assign(page_title: gettext("Edit fuel entry"), fuel_entry: fuel_entry)
        |> assign(preselect_vehicle: nil)
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That fuel entry could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/fuel")
    end
  end

  defp assign_lookups(socket, scope) do
    assign(socket, vehicles: vehicle_options(scope), members: member_options(scope))
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
        %{label: gettext("Fuel"), path: ~p"/o/#{org(assigns)}/fuel"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>{gettext("Log a refuel or recharge and what it cost.")}</:subtitle>
      </.header>

      <.form :let={f} for={@form} id="fuel-form" phx-change="validate" phx-submit="save" class="mt-6">
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <.search_select
              field={f[:vehicle_id]}
              value={f[:vehicle_id].value || @preselect_vehicle}
              label={gettext("Vehicle")}
              prompt={gettext("Select a vehicle")}
              options={@vehicles}
            />
            <.input field={f[:refueled_at]} type="datetime-local" label={gettext("Refueled at")} />

            <.input
              field={f[:odometer]}
              value={Format.distance_input(f[:odometer].value, org(assigns))}
              type="number"
              step="0.01"
              label={"#{gettext("Odometer")} (#{Format.distance_unit(org(assigns))})"}
              required
            />
            <.input
              field={f[:quantity]}
              value={Format.volume_input(f[:quantity].value, org(assigns))}
              type="number"
              step="0.01"
              label={"#{gettext("Quantity")} (#{Format.volume_unit(org(assigns))})"}
              required
            />

            <.money_field
              field={f[:cost]}
              label={gettext("Cost")}
              currencies={@currencies}
              default_currency={Format.default_currency(org(assigns))}
            />

            <.input
              field={f[:fuel_type]}
              type="select"
              label={gettext("Fuel type")}
              options={enum_options(FuelManagement.FuelType)}
            />

            <.input
              field={f[:payment_method]}
              type="select"
              label={gettext("Payment method")}
              prompt={gettext("—")}
              options={enum_options(FuelManagement.PaymentMethod)}
            />
            <.search_select
              field={f[:refueled_by_id]}
              label={gettext("Refueled by")}
              prompt={gettext("Select a member")}
              options={@members}
            />

            <div class="md:col-span-2">
              <.input field={f[:location]} type="text" label={gettext("Location")} />
            </div>
            <div class="md:col-span-2">
              <.input field={f[:notes]} type="textarea" label={gettext("Notes")} />
            </div>

            <div class="md:col-span-2">
              <label class="mb-2 block text-sm font-medium text-heading">
                {gettext("Receipt")}
              </label>

              <div class="flex items-start gap-4">
                <img
                  :if={@fuel_entry && storage_url(@fuel_entry.receipt_thumbnail_key)}
                  src={storage_url(@fuel_entry.receipt_thumbnail_key)}
                  alt={gettext("Current receipt")}
                  class="h-24 w-24 rounded-base border border-default object-cover"
                />

                <div class="flex-1">
                  <div
                    phx-drop-target={@uploads.receipt.ref}
                    class="rounded-base border border-dashed border-default-medium p-4 text-center text-sm text-body"
                  >
                    <.live_file_input
                      upload={@uploads.receipt}
                      aria-label={gettext("Receipt image")}
                      class="text-sm"
                    />
                    <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                      {gettext("JPG, PNG or WebP up to 10 MB. Replaces the current receipt.")}
                    </p>
                  </div>

                  <div :for={entry <- @uploads.receipt.entries} class="mt-2">
                    <div class="flex items-center gap-2 text-sm text-body">
                      <.live_img_preview entry={entry} class="h-12 w-12 rounded object-cover" />
                      <span class="truncate">{entry.client_name}</span>
                      <button
                        type="button"
                        phx-click="cancel-receipt"
                        phx-value-ref={entry.ref}
                        class="text-fg-danger hover:underline"
                      >
                        {gettext("Remove")}
                      </button>
                    </div>
                    <p
                      :for={err <- upload_errors(@uploads.receipt, entry)}
                      class="text-xs text-fg-danger"
                    >
                      {upload_error_to_string(err)}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save fuel entry")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/fuel"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  # Paired amount + currency control for a Money attribute. The inputs nest under
  # the field's name so the params arrive as `%{"amount" => _, "currency" => _}`,
  # which AshMoney casts to a Money.
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :currencies, :list, required: true
  attr :default_currency, :string, required: true

  defp money_field(assigns) do
    errors =
      if Phoenix.Component.used_input?(assigns.field),
        do: Enum.map(assigns.field.errors, &translate_error/1),
        else: []

    # Keep the org's currency selectable even if it's outside the curated shortlist.
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
  def handle_event("validate", %{"fuel_entry" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("cancel-receipt", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :receipt, ref)}
  end

  def handle_event("save", %{"fuel_entry" => params}, socket) do
    params =
      params
      |> to_canonical(socket)
      |> Map.merge(consume_receipt(socket))

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _fuel_entry} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Fuel entry saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/fuel")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  defp to_canonical(params, socket),
    do: Format.to_canonical_params(params, @unit_fields, org(socket))

  # --- money value helpers ---

  defp money_amount(%Money{amount: amount}), do: Decimal.to_string(amount, :normal)
  defp money_amount(%{"amount" => amount}), do: amount
  defp money_amount(%{amount: amount}) when not is_nil(amount), do: to_string(amount)
  defp money_amount(_), do: nil

  defp money_currency(%Money{currency: currency}, _default), do: to_string(currency)

  defp money_currency(%{"currency" => currency}, _default) when currency not in [nil, ""],
    do: to_string(currency)

  defp money_currency(%{currency: currency}, _default) when not is_nil(currency),
    do: to_string(currency)

  defp money_currency(_value, default), do: default

  # --- lookups ---

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp member_options(scope) do
    Accounts.list_user_organizations!(
      scope: scope,
      query: [filter: [organization_id: scope.organization.id, status: :active]],
      load: [user: [:email, profile: [:first_name, :last_name]]]
    )
    |> Enum.map(fn membership -> {member_label(membership.user), membership.user_id} end)
  end

  defp member_label(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp member_label(%{email: email}), do: to_string(email)

  defp enum_options(enum_module) do
    Enum.map(enum_module.values(), &{humanize_enum(&1), &1})
  end

  defp humanize_enum(value) do
    value |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  # Processes an uploaded receipt (if any) into a stored display image + thumbnail
  # and returns the keys as params for the create/update action. No upload → {}.
  defp consume_receipt(socket) do
    socket
    |> consume_uploaded_entries(:receipt, fn %{path: path}, _entry ->
      base = "fuel/receipts/#{Ecto.UUID.generate()}"
      image_key = base <> ".jpg"
      thumb_key = base <> "_thumb.jpg"
      display_tmp = tmp_path()
      thumb_tmp = tmp_path()

      try do
        with {:ok, _} <- Images.display(path, display_tmp),
             {:ok, _} <- Images.thumbnail(path, thumb_tmp),
             {:ok, _} <- Storage.put(image_key, display_tmp),
             {:ok, _} <- Storage.put(thumb_key, thumb_tmp) do
          {:ok, %{"receipt_image_key" => image_key, "receipt_thumbnail_key" => thumb_key}}
        else
          _ -> {:ok, :error}
        end
      after
        File.rm(display_tmp)
        File.rm(thumb_tmp)
      end
    end)
    |> case do
      [%{} = keys] -> keys
      _ -> %{}
    end
  end

  defp tmp_path, do: Path.join(System.tmp_dir!(), "fleetms-upload-#{Ecto.UUID.generate()}.jpg")

  defp storage_url(nil), do: nil
  defp storage_url(key), do: Storage.url(key)

  defp upload_error_to_string(:too_large), do: gettext("File is too large (max 10 MB).")
  defp upload_error_to_string(:not_accepted), do: gettext("That file type isn't allowed.")
  defp upload_error_to_string(:too_many_files), do: gettext("Only one receipt allowed.")
  defp upload_error_to_string(_), do: gettext("That file could not be uploaded.")
end
