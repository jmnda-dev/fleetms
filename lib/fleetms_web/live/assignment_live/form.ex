defmodule FleetmsWeb.AssignmentLive.Form do
  @moduledoc """
  Create / edit a vehicle assignment.

  A straightforward `AshPhoenix.Form` over the assignment's create/update action.
  Vehicle and assignee are searchable selects bound to the writable `vehicle_id` /
  `assignee_id` attributes. The start/end use native datetime-local inputs (the
  resource needs a time-of-day, which the date-only picker can't supply); the
  `color-scheme` styling keeps the native control on-theme.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Accounts
  alias Fleetms.Drivers
  alias Fleetms.Format
  alias Fleetms.VehicleManagement

  # Shown in the org's distance unit, stored canonically in km.
  @unit_fields %{"start_mileage" => :distance, "end_mileage" => :distance}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :assignments)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(VehicleManagement.VehicleAssignment, :create,
        domain: VehicleManagement,
        as: "assignment",
        scope: scope
      )

    socket
    |> assign(page_title: gettext("New assignment"), assignment: nil)
    |> assign(preselect_vehicle: params["vehicle_id"], current_vehicle_id: params["vehicle_id"])
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case VehicleManagement.get_vehicle_assignment(id, scope: scope) do
      {:ok, assignment} ->
        form =
          Form.for_update(assignment, :update,
            domain: VehicleManagement,
            as: "assignment",
            scope: scope
          )

        socket
        |> assign(
          page_title: gettext("Edit assignment"),
          assignment: assignment,
          preselect_vehicle: nil,
          current_vehicle_id: assignment.vehicle_id
        )
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That assignment could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/assignments")
    end
  end

  defp assign_lookups(socket, scope) do
    vehicles = vehicle_records(scope)

    assign(socket,
      vehicles: Enum.map(vehicles, &{&1.name, &1.id}),
      vehicle_mileages: Map.new(vehicles, &{&1.id, &1.mileage}),
      members: member_options(scope),
      drivers: driver_options(scope)
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
        %{label: gettext("Assignments"), path: ~p"/o/#{org(assigns)}/assignments"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>{gettext("Assign a vehicle to a member or a driver for a period.")}</:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="assignment-form"
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
              field={f[:assignee_id]}
              label={gettext("Member")}
              prompt={gettext("Select a member")}
              options={@members}
            />
            <.search_select
              field={f[:driver_id]}
              label={gettext("Driver")}
              prompt={gettext("…or a driver")}
              options={@drivers}
            />

            <.input
              field={f[:start_datetime]}
              type="datetime-local"
              label={gettext("Start")}
              required
            />
            <.input field={f[:end_datetime]} type="datetime-local" label={gettext("End")} />

            <.input
              field={f[:start_mileage]}
              value={Format.distance_input(f[:start_mileage].value, org(assigns))}
              type="number"
              step="0.01"
              label={"#{gettext("Start mileage")} (#{Format.distance_unit(org(assigns))})"}
              help={mileage_help(@vehicle_mileages, @current_vehicle_id, org(assigns))}
            />
            <.input
              field={f[:end_mileage]}
              value={Format.distance_input(f[:end_mileage].value, org(assigns))}
              type="number"
              step="0.01"
              label={"#{gettext("End mileage")} (#{Format.distance_unit(org(assigns))})"}
            />

            <div class="md:col-span-2">
              <.input field={f[:comments]} type="textarea" label={gettext("Comments")} />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save assignment")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/assignments"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"assignment" => params} = raw, socket) do
    params = exclusive_assignee(params, raw["_target"])

    {:noreply,
     socket
     |> assign(:form, Form.validate(socket.assigns.form, params))
     |> assign(:current_vehicle_id, params["vehicle_id"])}
  end

  def handle_event("save", %{"assignment" => params}, socket) do
    params = Format.to_canonical_params(params, @unit_fields, org(socket))

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _assignment} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Assignment saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/assignments")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  # A vehicle is assigned to exactly one of a member or a driver. When the user
  # picks one, clear the other so the two selects stay mutually exclusive (the
  # resource enforces it too).
  defp exclusive_assignee(params, ["assignment", "assignee_id"]) do
    if params["assignee_id"] in [nil, ""], do: params, else: Map.put(params, "driver_id", "")
  end

  defp exclusive_assignee(params, ["assignment", "driver_id"]) do
    if params["driver_id"] in [nil, ""], do: params, else: Map.put(params, "assignee_id", "")
  end

  defp exclusive_assignee(params, _target), do: params

  # --- lookups ---

  defp vehicle_records(scope) do
    case VehicleManagement.list_assignable_vehicles(scope: scope) do
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

  defp driver_options(scope) do
    Drivers.list_drivers!(
      scope: scope,
      query: [filter: [status: :active], sort: [last_name: :asc, first_name: :asc]],
      page: [limit: 100]
    ).results
    |> Enum.map(fn driver -> {driver_label(driver), driver.id} end)
  end

  defp driver_label(%{first_name: first, last_name: last}) do
    [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
