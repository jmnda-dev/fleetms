defmodule FleetmsWeb.WorkOrderLive.Form do
  @moduledoc """
  Create / edit a work order, with its nested service-task lines.

  An `AshPhoenix.Form` over the work order's create/update action. The action
  manages `work_order_service_tasks` (`direct_control`), each of which in turn
  manages its `work_order_service_task_parts` and `labor_items`, so AshPhoenix
  infers three levels of nested forms. Task/part/labour rows are added and removed
  with `AshPhoenix.Form.add_form/3` and `remove_form/2` by path.

  Money fields (part unit cost, labour rate / flat cost) render as paired
  amount + currency inputs whose names nest under the field, which AshMoney casts.
  The dynamically added nested selects are native `<select>`s (rather than the
  Tom Select `search_select`) so morphdom stays out of a JS-owned widget's way as
  rows are added and removed.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Accounts
  alias Fleetms.Format
  alias Fleetms.Inventory
  alias Fleetms.Maintenance
  alias Fleetms.Tagging
  alias Fleetms.VehicleIssues
  alias Fleetms.VehicleManagement

  # Shown in the org's distance unit, stored canonically in km.
  @unit_fields %{"mileage" => :distance}

  @currencies ~w(USD EUR GBP ZMW ZAR KES NGN GHS TZS UGX RWF INR JPY CNY CAD AUD)
  @default_currency "USD"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :maintenance, currencies: @currencies)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Maintenance.WorkOrder, :create,
        domain: Maintenance,
        as: "work_order",
        scope: scope
      )

    # Support pre-filling from another page (e.g. "Create work order" on an
    # issue): ?vehicle_id=…&issue_ids[]=… preselects the vehicle and links the
    # issues so the user lands on a ready-to-save form.
    preselect_issues =
      params["issue_ids"] |> List.wrap() |> Enum.reject(&(&1 in [nil, ""]))

    socket
    |> assign(
      page_title: gettext("New work order"),
      preselect_vehicle: params["vehicle_id"],
      selected_issue_ids: preselect_issues,
      current_vehicle_id: params["vehicle_id"],
      tags_value: [],
      vehicle_reminders: load_due_reminders(scope, params["vehicle_id"])
    )
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Maintenance.get_work_order(id,
           scope: scope,
           load: [
             :issues,
             :tags,
             work_order_service_tasks: [:work_order_service_task_parts, :labor_items]
           ]
         ) do
      {:ok, work_order} ->
        form =
          Form.for_update(work_order, :update,
            domain: Maintenance,
            as: "work_order",
            scope: scope
          )

        socket
        |> assign(
          page_title: gettext("Edit work order"),
          preselect_vehicle: nil,
          selected_issue_ids: Enum.map(work_order.issues, & &1.id),
          current_vehicle_id: work_order.vehicle_id,
          tags_value: Enum.map(work_order.tags, &to_string(&1.name)),
          vehicle_reminders: load_due_reminders(scope, work_order.vehicle_id)
        )
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That work order could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/work-orders")
    end
  end

  defp assign_lookups(socket, scope) do
    vehicles = vehicle_records(scope)

    assign(socket,
      vehicles: Enum.map(vehicles, &{&1.name, &1.id}),
      vehicle_mileages: Map.new(vehicles, &{&1.id, &1.mileage}),
      members: member_options(scope),
      tag_options: tag_options(scope),
      vendors: vendor_options(scope),
      service_tasks: service_task_options(scope),
      parts: part_options(scope),
      locations: location_options(scope),
      issue_options: issue_options(scope, socket.assigns.current_vehicle_id)
    )
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
        %{label: gettext("Work Orders"), path: ~p"/o/#{org(assigns)}/work-orders"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>
          {gettext("The work performed on a vehicle, with its parts and labour.")}
        </:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="work-order-form"
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
            <.search_select
              field={f[:assigned_to_id]}
              label={gettext("Assigned to")}
              prompt={gettext("Unassigned")}
              options={@members}
            />
            <.input
              field={f[:repair_category]}
              type="select"
              label={gettext("Repair category")}
              prompt={gettext("—")}
              options={enum_options(Maintenance.RepairCategory)}
            />
            <.input field={f[:issued_at]} type="datetime-local" label={gettext("Issued at")} />
            <.input
              field={f[:mileage]}
              value={Format.distance_input(f[:mileage].value, org(assigns))}
              type="number"
              step="0.01"
              label={"#{gettext("Odometer")} (#{Format.distance_unit(org(assigns))})"}
              help={mileage_help(@vehicle_mileages, @current_vehicle_id, org(assigns))}
            />
            <.input field={f[:hours]} type="number" step="0.01" label={gettext("Engine hours")} />
            <div class="md:col-span-2">
              <.input field={f[:description]} type="textarea" label={gettext("Description")} />
            </div>
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
              <.search_select
                id="work_order_issues"
                field={f[:issue_ids]}
                value={@selected_issue_ids}
                multiple
                rich
                disabled={@current_vehicle_id in [nil, ""]}
                label={gettext("Issues addressed")}
                prompt={
                  if @current_vehicle_id in [nil, ""],
                    do: gettext("Select a vehicle first…"),
                    else: gettext("Link this vehicle's open issues…")
                }
                options={@issue_options}
              />
              <p class="-mt-2 text-xs text-body">
                {gettext("Linked issues are resolved when this work order is completed.")}
              </p>
            </div>
          </div>
        </div>

        <div class="mt-6 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold uppercase text-heading">{gettext("Service tasks")}</h2>
            <.button
              type="button"
              size="sm"
              variant="secondary"
              phx-click="add-task"
              phx-value-path={f[:work_order_service_tasks].name}
            >
              <.icon name="fa-plus" class="me-2" /> {gettext("Add service task")}
            </.button>
          </div>

          <div
            :if={@vehicle_reminders != []}
            class="rounded-base border border-amber-300 bg-amber-50 p-4 dark:border-amber-900 dark:bg-amber-950/30"
          >
            <p class="mb-2 text-xs font-semibold uppercase text-amber-800 dark:text-amber-300">
              {gettext("Due on this vehicle — add as tasks")}
            </p>
            <div class="flex flex-wrap gap-2">
              <button
                :for={reminder <- @vehicle_reminders}
                type="button"
                phx-click="add-due-task"
                phx-value-path={f[:work_order_service_tasks].name}
                phx-value-task={reminder.service_task_id}
                class="inline-flex items-center gap-1.5 rounded-full border border-amber-300 bg-white px-3 py-1 text-sm text-heading hover:bg-amber-100 dark:border-amber-800 dark:bg-gray-800 dark:hover:bg-gray-700"
              >
                <.icon name="fa-plus" class="text-xs" />
                {reminder.service_task_name}
                <span class="text-xs text-amber-700 dark:text-amber-400">
                  {humanize_status(reminder.due_status)}
                </span>
              </button>
            </div>
          </div>

          <p
            :if={Enum.empty?(f[:work_order_service_tasks].value || [])}
            class="rounded-base border border-dashed border-default p-6 text-center text-sm text-body"
          >
            {gettext("No service tasks yet. Add one to record the work and its parts.")}
          </p>

          <.inputs_for :let={task} field={f[:work_order_service_tasks]}>
            <div class="rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800">
              <div class="flex items-start gap-3">
                <div class="flex-1">
                  <.input
                    field={task[:service_task_id]}
                    type="select"
                    label={gettext("Service task")}
                    prompt={gettext("Select a task")}
                    options={@service_tasks}
                  />
                  <p
                    :if={resets_reminder?(task, @vehicle_reminders)}
                    class="-mt-2 flex items-center gap-1 text-xs text-amber-700 dark:text-amber-400"
                  >
                    <.icon name="fa-rotate" class="text-xs" />
                    {gettext("Completing resets this vehicle's due reminder for this task.")}
                  </p>
                </div>
                <.button
                  type="button"
                  size="xs"
                  variant="danger"
                  class="mt-8"
                  phx-click="remove-form"
                  phx-value-path={task.name}
                >
                  <.icon name="fa-trash" />
                </.button>
              </div>

              <.parts_section
                task={task}
                parts={@parts}
                locations={@locations}
                currencies={@currencies}
              />
              <.labor_section
                task={task}
                members={@members}
                vendors={@vendors}
                currencies={@currencies}
              />
            </div>
          </.inputs_for>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save work order")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/work-orders"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  attr :task, :any, required: true
  attr :parts, :list, required: true
  attr :locations, :list, required: true
  attr :currencies, :list, required: true

  defp parts_section(assigns) do
    ~H"""
    <div class="mt-4 border-t border-default pt-4">
      <div class="mb-2 flex items-center justify-between">
        <h3 class="text-xs font-semibold uppercase text-body">{gettext("Parts")}</h3>
        <.button
          type="button"
          size="xs"
          variant="secondary"
          phx-click="add-part"
          phx-value-path={@task[:work_order_service_task_parts].name}
        >
          <.icon name="fa-plus" class="me-1" /> {gettext("Add part")}
        </.button>
      </div>

      <.inputs_for :let={part} field={@task[:work_order_service_task_parts]}>
        <div class="mb-3 grid gap-3 rounded-base bg-gray-50 p-3 dark:bg-gray-700/40 md:grid-cols-12">
          <div class="md:col-span-4">
            <.input
              field={part[:part_id]}
              type="select"
              label={gettext("Part")}
              prompt={gettext("Select a part")}
              options={@parts}
            />
          </div>
          <div class="md:col-span-2">
            <.input field={part[:quantity]} type="number" step="0.01" label={gettext("Qty")} />
          </div>
          <div class="md:col-span-3">
            <.money_field
              field={part[:unit_cost]}
              label={gettext("Unit cost")}
              currencies={@currencies}
            />
          </div>
          <div class="md:col-span-2">
            <.input
              field={part[:inventory_location_id]}
              type="select"
              label={gettext("Location")}
              prompt={gettext("—")}
              options={@locations}
              help={gettext("Draws from this location's stock on completion.")}
            />
          </div>
          <div class="flex items-end justify-end md:col-span-1">
            <.button
              type="button"
              size="xs"
              variant="danger"
              class="mb-4"
              phx-click="remove-form"
              phx-value-path={part.name}
            >
              <.icon name="fa-trash" />
            </.button>
          </div>
        </div>
      </.inputs_for>
    </div>
    """
  end

  attr :task, :any, required: true
  attr :members, :list, required: true
  attr :vendors, :list, required: true
  attr :currencies, :list, required: true

  defp labor_section(assigns) do
    ~H"""
    <div class="mt-4 border-t border-default pt-4">
      <div class="mb-2 flex items-center justify-between">
        <h3 class="text-xs font-semibold uppercase text-body">{gettext("Labour")}</h3>
        <.button
          type="button"
          size="xs"
          variant="secondary"
          phx-click="add-labor"
          phx-value-path={@task[:labor_items].name}
        >
          <.icon name="fa-plus" class="me-1" /> {gettext("Add labour")}
        </.button>
      </div>

      <.inputs_for :let={labor} field={@task[:labor_items]}>
        <div class="mb-3 grid gap-3 rounded-base bg-gray-50 p-3 dark:bg-gray-700/40 md:grid-cols-12">
          <div class="md:col-span-3">
            <.input
              field={labor[:labor_type]}
              type="select"
              label={gettext("Type")}
              options={[{gettext("Technician"), "technician"}, {gettext("Vendor"), "vendor"}]}
            />
          </div>

          <%= if to_string(labor[:labor_type].value) == "vendor" do %>
            <div class="md:col-span-4">
              <.input
                field={labor[:vendor_id]}
                type="select"
                label={gettext("Vendor")}
                prompt={gettext("Select a vendor")}
                options={@vendors}
              />
            </div>
            <div class="md:col-span-4">
              <.money_field
                field={labor[:flat_cost]}
                label={gettext("Flat cost")}
                currencies={@currencies}
              />
            </div>
          <% else %>
            <div class="md:col-span-3">
              <.input
                field={labor[:technician_id]}
                type="select"
                label={gettext("Technician")}
                prompt={gettext("Select a member")}
                options={@members}
              />
            </div>
            <div class="md:col-span-2">
              <.input field={labor[:hours]} type="number" step="0.01" label={gettext("Hours")} />
            </div>
            <div class="md:col-span-3">
              <.money_field
                field={labor[:hourly_rate]}
                label={gettext("Rate/hr")}
                currencies={@currencies}
              />
            </div>
          <% end %>

          <div class="flex items-end justify-end md:col-span-1">
            <.button
              type="button"
              size="xs"
              variant="danger"
              class="mb-4"
              phx-click="remove-form"
              phx-value-path={labor.name}
            >
              <.icon name="fa-trash" />
            </.button>
          </div>
        </div>
      </.inputs_for>
    </div>
    """
  end

  # Paired amount + currency control for a Money attribute; the inputs nest under
  # the field name so the params arrive as %{"amount" => _, "currency" => _}.
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
          class="block w-24 shrink-0 rounded-base border border-default-medium bg-neutral-secondary-medium px-2 py-2.5 text-sm text-heading shadow-xs focus:border-brand focus:ring-brand"
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
  def handle_event("validate", %{"work_order" => params}, socket) do
    vehicle_id = params["vehicle_id"]
    vehicle_changed? = vehicle_id != socket.assigns.current_vehicle_id

    # Switching vehicle clears any issues linked to the old one — they can't apply to a
    # different vehicle. Drop them from the params so the form doesn't keep them either.
    params = if vehicle_changed?, do: Map.put(params, "issue_ids", []), else: params

    selected =
      if vehicle_changed?,
        do: [],
        else: List.wrap(params["issue_ids"]) |> Enum.reject(&(&1 in [nil, ""]))

    socket =
      socket
      |> assign(:form, Form.validate(socket.assigns.form, normalize(params)))
      |> assign(:selected_issue_ids, selected)

    socket = if vehicle_changed?, do: reload_for_vehicle(socket, vehicle_id), else: socket

    {:noreply, socket}
  end

  def handle_event("save", %{"work_order" => params}, socket) do
    params =
      params
      |> Format.to_canonical_params(@unit_fields, org(socket))
      |> normalize()

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, work_order} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Work order saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/work-orders/#{work_order.id}")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  def handle_event("add-task", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, Form.add_form(socket.assigns.form, path))}
  end

  def handle_event("add-part", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, Form.add_form(socket.assigns.form, path))}
  end

  def handle_event("add-labor", %{"path" => path}, socket) do
    form = Form.add_form(socket.assigns.form, path, params: %{"labor_type" => "technician"})
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("remove-form", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, Form.remove_form(socket.assigns.form, path))}
  end

  # Add a service-task line pre-filled with a due reminder's task (one-click seed).
  def handle_event("add-due-task", %{"path" => path, "task" => task_id}, socket) do
    form = Form.add_form(socket.assigns.form, path, params: %{"service_task_id" => task_id})
    {:noreply, assign(socket, :form, form)}
  end

  # A blank datetime-local input arrives as "", which would override issued_at's
  # default with nil (it's required). Drop it so the default (now) stands in.
  defp normalize(%{"issued_at" => ""} = params), do: Map.delete(params, "issued_at")
  defp normalize(params), do: params

  # The selected vehicle's due-soon/overdue reminders, reloaded when the vehicle
  # changes so the "seed" panel and the per-line "resets a reminder" badge stay in
  # sync with the picker.
  # The selected vehicle changed: refresh everything scoped to it — the due reminders,
  # and the linkable open issues (repopulating and re-enabling their picker, or disabling
  # it when the vehicle was cleared).
  defp reload_for_vehicle(socket, vehicle_id) do
    scope = socket.assigns.current_scope
    options = issue_options(scope, vehicle_id)

    socket
    |> assign(
      current_vehicle_id: vehicle_id,
      issue_options: options,
      vehicle_reminders: load_due_reminders(scope, vehicle_id)
    )
    |> push_event("tomselect:options:work_order_issues", %{
      options: options,
      value: nil,
      disabled: vehicle_id in [nil, ""]
    })
  end

  defp load_due_reminders(_scope, id) when id in [nil, ""], do: []

  defp load_due_reminders(scope, vehicle_id) do
    vehicle_id
    |> Maintenance.list_vehicle_service_reminders!(scope: scope)
    |> page_results()
    |> Enum.filter(&(&1.due_status in [:due_soon, :overdue]))
  end

  defp page_results(%{results: results}), do: results
  defp page_results(list) when is_list(list), do: list

  # Does this service-task line's chosen task match one of the vehicle's due reminders?
  defp resets_reminder?(task_form, reminders) do
    value = task_form[:service_task_id].value

    value not in [nil, ""] and
      Enum.any?(reminders, &(to_string(&1.service_task_id) == to_string(value)))
  end

  defp humanize_status(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

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

  # --- lookups ---

  defp vehicle_records(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> vehicles
      _ -> []
    end
  end

  defp mileage_help(_mileages, id, _org) when id in [nil, ""], do: nil

  defp mileage_help(mileages, id, org) do
    case Map.get(mileages, id) do
      nil -> nil
      mileage -> gettext("Current odometer: %{m}", m: Format.distance(mileage, org))
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

  defp vendor_options(scope) do
    Maintenance.list_vendors!(%{}, scope: scope) |> Enum.map(&{&1.name, &1.id})
  end

  defp service_task_options(scope) do
    Maintenance.list_service_tasks!(%{}, scope: scope) |> Enum.map(&{&1.name, &1.id})
  end

  # Existing tag names for autocomplete; value == name so picked and typed entries alike
  # are names the action can relate-or-create.
  defp tag_options(scope) do
    Tagging.list_tags!(scope: scope) |> Enum.map(&{to_string(&1.name), to_string(&1.name)})
  end

  # Open issues, offered as rich options to link to the work order.
  # Open issues for the chosen vehicle only — a work order is for one vehicle, so you
  # can only link that vehicle's issues. No vehicle chosen yet → nothing to offer.
  defp issue_options(_scope, vehicle_id) when vehicle_id in [nil, ""], do: []

  defp issue_options(scope, vehicle_id) do
    case VehicleIssues.list_issues(%{}, scope: scope, page: [limit: 200], load: [:vehicle]) do
      {:ok, page} ->
        page.results
        |> Enum.filter(&(&1.status == :open and &1.vehicle_id == vehicle_id))
        |> Enum.map(&issue_option/1)

      _ ->
        []
    end
  end

  defp issue_option(issue) do
    %{
      value: issue.id,
      label: "##{issue.issue_number} — #{issue.title}",
      subtitle: issue_subtitle(issue)
    }
  end

  defp issue_subtitle(%{vehicle: %{name: name}} = issue), do: "#{name} · #{issue.priority}"
  defp issue_subtitle(issue), do: to_string(issue.priority)

  defp part_options(scope) do
    Inventory.list_parts!(%{}, scope: scope, page: [limit: 500])
    |> Map.get(:results, [])
    |> Enum.map(&{part_label(&1), &1.id})
  end

  defp part_label(%{part_number: number, name: nil}), do: number
  defp part_label(%{part_number: number, name: name}), do: "#{number} — #{name}"

  defp location_options(scope) do
    Inventory.list_inventory_locations!(%{}, scope: scope) |> Enum.map(&{&1.name, &1.id})
  end

  defp enum_options(enum_module) do
    Enum.map(enum_module.values(), &{humanize_enum(&1), &1})
  end

  defp humanize_enum(value) do
    value |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
