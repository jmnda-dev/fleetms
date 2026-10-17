defmodule FleetmsWeb.ServiceGroupLive.Form do
  @moduledoc """
  Create / edit a service group: its name, its schedule lines (each a service task
  + intervals, added/removed inline as AshPhoenix nested forms), and the vehicles it
  applies to.

  Vehicles are chosen with a `rich` multi-select (name + make/plate/mileage
  subtitle); the current selection is mirrored below as read-only cards so a large
  membership is easy to scan. Saving fans out / syncs the reminders on the backend.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Maintenance
  alias Fleetms.VehicleManagement

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
    selected = List.wrap(params["vehicle_id"])

    form =
      Form.for_create(Maintenance.ServiceGroup, :create,
        domain: Maintenance,
        as: "service_group",
        actor: scope.user,
        tenant: scope.organization
      )

    socket
    |> assign(page_title: gettext("New service group"), selected_vehicle_ids: selected)
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Maintenance.get_service_group(id, scope: scope) do
      {:ok, group} ->
        form =
          Form.for_update(group, :update,
            domain: Maintenance,
            as: "service_group",
            actor: scope.user,
            tenant: scope.organization
          )

        socket
        |> assign(
          page_title: gettext("Edit service group"),
          selected_vehicle_ids: Enum.map(group.vehicles, & &1.id)
        )
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That service group could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/service-groups")
    end
  end

  defp assign_lookups(socket, scope) do
    vehicles = vehicle_records(scope)

    assign(socket,
      vehicles: vehicles,
      vehicle_options: Enum.map(vehicles, &vehicle_option/1),
      service_tasks: service_task_options(scope)
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
        %{label: gettext("Service Groups"), path: ~p"/o/#{org(assigns)}/service-groups"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>
          {gettext("Its schedule lines fan out to every member vehicle as reminders.")}
        </:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="service-group-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 md:grid-cols-2">
            <.input field={f[:name]} type="text" label={gettext("Name")} required />
            <.input field={f[:description]} type="text" label={gettext("Description")} />
          </div>
        </div>

        <div class="mt-6 space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-semibold uppercase text-heading">{gettext("Schedule lines")}</h3>
            <.button
              type="button"
              size="sm"
              variant="secondary"
              phx-click="add-schedule"
              phx-value-path={f[:schedules].name}
            >
              <.icon name="fa-plus" class="me-2" /> {gettext("Add schedule line")}
            </.button>
          </div>

          <p
            :if={Enum.empty?(f[:schedules].value || [])}
            class="rounded-base border border-dashed border-default p-6 text-center text-sm text-body"
          >
            {gettext("No schedule lines yet. Each is a task and how often it recurs.")}
          </p>

          <.inputs_for :let={sched} field={f[:schedules]}>
            <div class="rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800">
              <div class="flex items-start gap-3">
                <div class="flex-1">
                  <.input
                    field={sched[:service_task_id]}
                    value={schedule_task_value(sched)}
                    type="select"
                    label={gettext("Service task")}
                    prompt={gettext("Select a task")}
                    options={@service_tasks}
                  />
                </div>
                <.button
                  type="button"
                  size="xs"
                  variant="danger"
                  class="mt-8"
                  phx-click="remove-form"
                  phx-value-path={sched.name}
                >
                  <.icon name="fa-trash" />
                </.button>
              </div>

              <div class="grid gap-3 md:grid-cols-3">
                <.input
                  field={sched[:mileage_interval]}
                  type="number"
                  step="1"
                  label={gettext("Every (mi/km)")}
                />
                <.input
                  field={sched[:mileage_threshold]}
                  type="number"
                  step="1"
                  label={gettext("Mileage warn-before")}
                />
                <div></div>
                <.input
                  field={sched[:time_interval]}
                  type="number"
                  step="1"
                  label={gettext("Every (time)")}
                />
                <.input
                  field={sched[:time_interval_unit]}
                  type="select"
                  label={gettext("Unit")}
                  prompt={gettext("—")}
                  options={unit_options()}
                />
                <.input
                  field={sched[:time_threshold_days]}
                  type="number"
                  step="1"
                  label={gettext("Days warn-before")}
                />
              </div>
            </div>
          </.inputs_for>
        </div>

        <div class="mt-6 rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <h3 class="mb-3 text-sm font-semibold uppercase text-heading">{gettext("Vehicles")}</h3>
          <.search_select
            field={f[:vehicle_ids]}
            value={@selected_vehicle_ids}
            multiple
            rich
            label={gettext("Vehicles in this group")}
            prompt={gettext("Search and add vehicles…")}
            options={@vehicle_options}
          />

          <div :if={@selected_vehicle_ids != []} class="mt-2 grid gap-2 sm:grid-cols-2">
            <div
              :for={vehicle <- selected_vehicles(@vehicles, @selected_vehicle_ids)}
              class="rounded-base border border-default px-3 py-2"
            >
              <p class="text-sm font-medium text-heading">{vehicle.name}</p>
              <p class="text-xs text-body">{vehicle_subtitle(vehicle)}</p>
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save group")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/service-groups"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"service_group" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    selected = List.wrap(params["vehicle_ids"]) |> Enum.reject(&(&1 in [nil, ""]))
    {:noreply, assign(socket, form: form, selected_vehicle_ids: selected)}
  end

  def handle_event("save", %{"service_group" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _group} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Service group saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/service-groups")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  def handle_event("add-schedule", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, Form.add_form(socket.assigns.form, path))}
  end

  def handle_event("remove-form", %{"path" => path}, socket) do
    {:noreply, assign(socket, :form, Form.remove_form(socket.assigns.form, path))}
  end

  # --- lookups / helpers ---

  # The selected task for a schedule line: the submitted value if present, else the
  # existing record's value on edit. A freshly added line has no data record (nil),
  # so guard against it.
  defp schedule_task_value(sched) do
    case sched[:service_task_id].value do
      nil -> data_task_id(sched.data)
      value -> value
    end
  end

  defp data_task_id(%{service_task_id: id}), do: id
  defp data_task_id(_), do: nil

  defp unit_options do
    Enum.map(Maintenance.TimeUnit.values(), &{&1 |> to_string() |> String.capitalize(), &1})
  end

  defp vehicle_records(scope) do
    case VehicleManagement.list_vehicles(%{sort_by: :name, sort_order: :asc},
           scope: scope,
           page: [limit: 500]
         ) do
      {:ok, page} -> page.results
      _ -> []
    end
  end

  defp vehicle_option(vehicle) do
    %{value: vehicle.id, label: vehicle.name, subtitle: vehicle_subtitle(vehicle)}
  end

  defp vehicle_subtitle(vehicle) do
    [vehicle.license_plate, mileage_label(vehicle.mileage)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  defp mileage_label(nil), do: nil
  defp mileage_label(mileage), do: "#{Decimal.to_string(mileage, :normal)} mi"

  defp selected_vehicles(vehicles, selected_ids) do
    Enum.filter(vehicles, &(&1.id in selected_ids))
  end

  defp service_task_options(scope) do
    Maintenance.list_service_tasks!(%{}, scope: scope) |> Enum.map(&{&1.name, &1.id})
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
