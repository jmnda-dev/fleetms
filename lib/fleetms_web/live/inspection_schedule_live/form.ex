defmodule FleetmsWeb.InspectionScheduleLive.Form do
  @moduledoc """
  Create or edit a recurring inspection schedule: which form on which vehicle, how
  often (a day interval), from when, and who is responsible. The form and vehicle
  are fixed once created (they identify the schedule), so editing adjusts only the
  cadence, anchor, assignee, name and active flag.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.{Accounts, Inspections, VehicleManagement}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :inspections)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope

    socket =
      assign(socket,
        form_options: form_options(scope),
        vehicle_options: vehicle_options(scope),
        member_options: member_options(scope)
      )

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(Inspections.InspectionSchedule, :create,
        domain: Inspections,
        as: "schedule",
        actor: scope.user,
        tenant: scope.organization
      )

    socket
    |> assign(page_title: gettext("New schedule"), schedule: nil)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Inspections.get_inspection_schedule(id, scope: scope) do
      {:ok, schedule} ->
        form =
          Form.for_update(schedule, :update,
            domain: Inspections,
            as: "schedule",
            actor: scope.user,
            tenant: scope.organization
          )

        socket
        |> assign(page_title: gettext("Edit schedule"), schedule: schedule)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That schedule could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/inspection-schedules")
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
        %{label: gettext("Dashboard"), path: ~p"/o/#{org(assigns)}", icon: "fa-house"},
        %{label: gettext("Inspection Schedules"), path: ~p"/o/#{org(assigns)}/inspection-schedules"},
        %{label: @page_title}
      ]} />

      <.header>{@page_title}</.header>

      <.form
        :let={f}
        for={@form}
        id="inspection-schedule-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <div class="rounded-base border border-default bg-white p-6 shadow-sm dark:bg-gray-800">
          <div class="grid gap-4 sm:grid-cols-2">
            <%= if @live_action == :new do %>
              <.input
                field={f[:inspection_form_id]}
                type="select"
                label={gettext("Inspection form")}
                prompt={gettext("Select a form…")}
                options={@form_options}
                required
              />
              <.input
                field={f[:vehicle_id]}
                type="select"
                label={gettext("Vehicle")}
                prompt={gettext("Select a vehicle…")}
                options={@vehicle_options}
                required
              />
            <% else %>
              <div>
                <span class="block text-sm font-medium text-heading">
                  {gettext("Inspection form")}
                </span>
                <p class="mt-2 text-sm text-body">{@schedule.inspection_form.title}</p>
              </div>
              <div>
                <span class="block text-sm font-medium text-heading">{gettext("Vehicle")}</span>
                <p class="mt-2 text-sm text-body">{@schedule.vehicle.name}</p>
              </div>
            <% end %>

            <.input
              field={f[:interval_days]}
              type="number"
              min="1"
              label={gettext("Repeat every (days)")}
              help={gettext("1 = daily, 7 = weekly, 14 = fortnightly.")}
              required
            />
            <.input field={f[:start_date]} type="date" label={gettext("Starts on")} required />

            <.input
              field={f[:assigned_to_id]}
              type="select"
              label={gettext("Assign to")}
              prompt={gettext("Unassigned")}
              options={@member_options}
            />
            <.input
              field={f[:name]}
              type="text"
              label={gettext("Name")}
              help={gettext("Optional label, e.g. “Daily pre-trip”.")}
            />
          </div>

          <label class="mt-4 flex items-center gap-2 text-sm text-body">
            <.input field={f[:active]} type="checkbox" /> {gettext("Active")}
          </label>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save schedule")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/inspection-schedules"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"schedule" => params}, socket) do
    {:noreply, assign(socket, :form, Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"schedule" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _schedule} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Schedule saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/inspection-schedules")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  defp form_options(scope) do
    case Inspections.list_inspection_forms(%{}, scope: scope, page: [limit: 200]) do
      {:ok, page} ->
        page.results |> Enum.filter(&(&1.status == :active)) |> Enum.map(&{&1.title, &1.id})

      _ ->
        []
    end
  end

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
    |> Enum.map(fn membership -> {member_name(membership.user), membership.user_id} end)
  end

  defp member_name(%{profile: %{first_name: first, last_name: last}} = user) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp member_name(%{email: email}), do: to_string(email)

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
