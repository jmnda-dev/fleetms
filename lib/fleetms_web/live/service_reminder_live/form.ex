defmodule FleetmsWeb.ServiceReminderLive.Form do
  @moduledoc """
  Create / edit a service reminder.

  On create, the vehicle and service task are chosen (they form the reminder's
  identity); on edit they're fixed, so only the intervals and "due soon" thresholds
  are editable. A reminder needs at least a mileage or a time interval.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Format
  alias Fleetms.Maintenance
  alias Fleetms.VehicleManagement

  # Mileage intervals are entered in the org's distance unit, stored canonically in km.
  @unit_fields %{"mileage_interval" => :distance, "mileage_threshold" => :distance}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :maintenance)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Maintenance.ServiceReminder, :create,
        domain: Maintenance,
        as: "service_reminder",
        scope: scope
      )

    socket
    |> assign(
      page_title: gettext("New service reminder"),
      reminder: nil,
      preselect_vehicle: params["vehicle_id"]
    )
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Maintenance.get_service_reminder(id, scope: scope) do
      {:ok, reminder} ->
        form =
          Form.for_update(reminder, :update,
            domain: Maintenance,
            as: "service_reminder",
            scope: scope
          )

        socket
        |> assign(page_title: gettext("Edit service reminder"), reminder: reminder)
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That service reminder could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/service-reminders")
    end
  end

  defp assign_lookups(socket, scope) do
    assign(socket, vehicles: vehicle_options(scope), service_tasks: service_task_options(scope))
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
        %{label: gettext("Service Reminders"), path: ~p"/o/#{org(assigns)}/service-reminders"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>{gettext("Due by mileage, by time, or both.")}</:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="service-reminder-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div :if={@reminder} class="mb-4 grid gap-4 md:grid-cols-2">
            <div>
              <p class="text-sm font-medium text-heading">{gettext("Vehicle")}</p>
              <p class="text-sm text-body">{@reminder.vehicle.name}</p>
            </div>
            <div>
              <p class="text-sm font-medium text-heading">{gettext("Service task")}</p>
              <p class="text-sm text-body">{@reminder.service_task_name}</p>
            </div>
          </div>

          <div :if={is_nil(@reminder)} class="grid gap-4 md:grid-cols-2">
            <.search_select
              field={f[:vehicle_id]}
              value={f[:vehicle_id].value || @preselect_vehicle}
              label={gettext("Vehicle")}
              prompt={gettext("Select a vehicle")}
              options={@vehicles}
            />
            <.search_select
              field={f[:service_task_id]}
              label={gettext("Service task")}
              prompt={gettext("Select a task")}
              options={@service_tasks}
            />
          </div>

          <div class="mt-4 border-t border-default pt-4">
            <h3 class="mb-3 text-sm font-semibold uppercase text-heading">{gettext("Mileage")}</h3>
            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={f[:mileage_interval]}
                value={Format.distance_input(f[:mileage_interval].value, org(assigns))}
                type="number"
                step="1"
                label={"#{gettext("Every")} (#{Format.distance_unit(org(assigns))})"}
              />
              <.input
                field={f[:mileage_threshold]}
                value={Format.distance_input(f[:mileage_threshold].value, org(assigns))}
                type="number"
                step="1"
                label={"#{gettext("Warn this far before")} (#{Format.distance_unit(org(assigns))})"}
              />
            </div>
          </div>

          <div class="mt-4 border-t border-default pt-4">
            <h3 class="mb-3 text-sm font-semibold uppercase text-heading">{gettext("Time")}</h3>
            <div class="grid gap-4 md:grid-cols-3">
              <.input field={f[:time_interval]} type="number" step="1" label={gettext("Every")} />
              <.input
                field={f[:time_interval_unit]}
                type="select"
                label={gettext("Unit")}
                prompt={gettext("—")}
                options={unit_options()}
              />
              <.input
                field={f[:time_threshold_days]}
                type="number"
                step="1"
                label={gettext("Warn this many days before")}
              />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save reminder")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/service-reminders"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"service_reminder" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"service_reminder" => params}, socket) do
    params = Format.to_canonical_params(params, @unit_fields, org(socket))

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _reminder} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Service reminder saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/service-reminders")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  defp unit_options do
    Enum.map(Maintenance.TimeUnit.values(), fn unit ->
      {unit |> to_string() |> String.capitalize(), unit}
    end)
  end

  defp vehicle_options(scope) do
    case VehicleManagement.list_vehicles(%{sort_by: :name, sort_order: :asc},
           scope: scope,
           page: [limit: 200]
         ) do
      {:ok, page} -> Enum.map(page.results, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp service_task_options(scope) do
    Maintenance.list_service_tasks!(%{}, scope: scope) |> Enum.map(&{&1.name, &1.id})
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
