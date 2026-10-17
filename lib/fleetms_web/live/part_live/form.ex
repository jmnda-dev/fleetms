defmodule FleetmsWeb.PartLive.Form do
  @moduledoc """
  Create / edit a part (catalogue fields). An `AshPhoenix.Form` over the part's
  create/update action.

  Unit cost is a `Money` value rendered as a paired amount + currency control
  (nested `part[unit_cost][amount]` / `[currency]`, which AshMoney casts). Category
  is a searchable/creatable select resolved (find-or-create by name) on submit,
  like renewal types. Stock is managed separately (per location) — not on this form.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Inventory
  alias Fleetms.Tagging

  @currencies ~w(USD EUR GBP ZMW ZAR KES NGN GHS TZS UGX RWF INR JPY CNY CAD AUD)
  @default_currency "USD"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :inventory, currencies: @currencies)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Inventory.Part, :create,
        domain: Inventory,
        as: "part",
        actor: scope.user,
        tenant: scope.organization
      )

    socket
    |> assign(page_title: gettext("New part"), category_value: nil, tags_value: [])
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Inventory.get_part(id, scope: scope, load: [:tags]) do
      {:ok, part} ->
        form =
          Form.for_update(part, :update,
            domain: Inventory,
            as: "part",
            actor: scope.user,
            tenant: scope.organization
          )

        socket
        |> assign(
          page_title: gettext("Edit part"),
          category_value: part.category_id,
          tags_value: Enum.map(part.tags, &to_string(&1.name))
        )
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That part could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/parts")
    end
  end

  defp assign_lookups(socket, scope) do
    assign(socket, categories: category_records(scope), tag_options: tag_options(scope))
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
        %{label: gettext("Parts"), path: ~p"/o/#{org(assigns)}/parts"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>{gettext("Catalogue details. Stock is managed per location.")}</:subtitle>
      </.header>

      <.form :let={f} for={@form} id="part-form" phx-change="validate" phx-submit="save" class="mt-6">
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <.input field={f[:part_number]} type="text" label={gettext("Part number")} required />
            <.input field={f[:name]} type="text" label={gettext("Name")} />

            <.search_select
              id="part_category"
              name="category"
              value={@category_value}
              create
              label={gettext("Category")}
              prompt={gettext("Search or add a category…")}
              options={Enum.map(@categories, &{&1.name, &1.id})}
            />
            <.input field={f[:manufacturer]} type="text" label={gettext("Manufacturer")} />

            <.input field={f[:oem_part_number]} type="text" label={gettext("OEM part number")} />
            <.input field={f[:unit_measurement]} type="text" label={gettext("Unit (each, litre…)")} />

            <.money_field field={f[:unit_cost]} label={gettext("Unit cost")} currencies={@currencies} />

            <div class="md:col-span-2">
              <.search_select
                field={f[:tags]}
                value={@tags_value}
                multiple
                create
                options={@tag_options}
                label={gettext("Tags")}
                prompt={gettext("Add tags…")}
              />
            </div>

            <div class="md:col-span-2">
              <.input field={f[:description]} type="textarea" label={gettext("Description")} />
            </div>
          </div>

          <div class="mt-6 border-t border-default pt-6">
            <h2 class="mb-4 text-sm font-semibold uppercase text-heading">{gettext("Inventory")}</h2>
            <.input
              field={f[:track_inventory]}
              type="checkbox"
              label={gettext("Track stock levels for this part")}
            />
            <div class="mt-2 max-w-xs">
              <.input
                field={f[:quantity_threshold]}
                type="number"
                step="0.01"
                label={gettext("Reorder threshold")}
              />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save part")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/parts"}>
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

  defp money_field(assigns) do
    errors =
      if Phoenix.Component.used_input?(assigns.field),
        do: Enum.map(assigns.field.errors, &translate_error/1),
        else: []

    assigns = assign(assigns, errors: errors)

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
          {Phoenix.HTML.Form.options_for_select(@currencies, money_currency(@field.value))}
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
  def handle_event("validate", %{"part" => params} = all, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form, category_value: all["category"])}
  end

  def handle_event("save", %{"part" => params} = all, socket) do
    scope = socket.assigns.current_scope
    category = resolve_category(scope, socket.assigns.categories, all["category"])
    params = Map.put(params, "category_id", category && category.id)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _part} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Part saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/parts")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: form, category_value: all["category"])
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  # --- find-or-create category ---

  defp resolve_category(_scope, _categories, value) when value in [nil, ""], do: nil

  defp resolve_category(scope, categories, value) do
    case Enum.find(categories, &(&1.id == value)) do
      nil -> Inventory.upsert_part_category!(%{name: value}, scope: scope)
      category -> category
    end
  end

  # --- money value helpers ---

  defp money_amount(%Money{amount: amount}), do: Decimal.to_string(amount, :normal)
  defp money_amount(%{"amount" => amount}), do: amount
  defp money_amount(%{amount: amount}) when not is_nil(amount), do: to_string(amount)
  defp money_amount(_), do: nil

  defp money_currency(%Money{currency: currency}), do: to_string(currency)

  defp money_currency(%{"currency" => currency}) when currency not in [nil, ""],
    do: to_string(currency)

  defp money_currency(%{currency: currency}) when not is_nil(currency), do: to_string(currency)
  defp money_currency(_), do: @default_currency

  defp category_records(scope) do
    Inventory.list_part_categories!(scope: scope, query: [sort: [name: :asc]])
  end

  # Existing tag names for autocomplete; value == name so picked and typed entries alike
  # are names the action can relate-or-create.
  defp tag_options(scope) do
    Tagging.list_tags!(scope: scope) |> Enum.map(&{to_string(&1.name), to_string(&1.name)})
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
