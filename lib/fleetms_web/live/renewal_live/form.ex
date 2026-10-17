defmodule FleetmsWeb.RenewalLive.Form do
  @moduledoc """
  Create / edit a vehicle renewal.

  An `AshPhoenix.Form` over the renewal's create/update action. The vehicle is a
  searchable select bound to `vehicle_id`; the renewal type is a
  searchable/creatable select resolved (find-or-create by name) on submit, like
  vehicle makes. Recurrence and "notify before" are optional amount+unit pairs.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.VehicleManagement

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :renewals)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(VehicleManagement.VehicleRenewal, :create,
        domain: VehicleManagement,
        as: "renewal",
        scope: scope
      )

    socket
    |> assign(page_title: gettext("New renewal"), renewal: nil)
    |> assign(preselect_vehicle: params["vehicle_id"], type_value: nil)
    |> assign_lookups(scope)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case VehicleManagement.get_vehicle_renewal(id, scope: scope) do
      {:ok, renewal} ->
        form =
          Form.for_update(renewal, :update,
            domain: VehicleManagement,
            as: "renewal",
            scope: scope
          )

        socket
        |> assign(page_title: gettext("Edit renewal"), renewal: renewal, preselect_vehicle: nil)
        |> assign(type_value: renewal.renewal_type_id)
        |> assign_lookups(scope)
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That renewal could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/renewals")
    end
  end

  defp assign_lookups(socket, scope) do
    assign(socket, vehicles: vehicle_options(scope), types: type_records(scope))
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
        %{label: gettext("Renewals"), path: ~p"/o/#{org(assigns)}/renewals"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>
          {gettext("Track a date-based renewal like insurance or roadworthiness.")}
        </:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="renewal-form"
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
              id="renewal_type"
              name="renewal_type"
              value={@type_value}
              create
              label={gettext("Type")}
              prompt={gettext("Search or add a type…")}
              options={Enum.map(@types, &{&1.name, &1.id})}
            />

            <.date_input field={f[:due_date]} label={gettext("Due date")} />
            <div class="hidden md:block"></div>

            <div class="grid grid-cols-2 gap-3">
              <.input field={f[:recurrence_interval]} type="number" label={gettext("Repeats every")} />
              <.search_select
                field={f[:recurrence_unit]}
                label={gettext("Unit")}
                prompt={gettext("—")}
                options={time_unit_options()}
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <.input field={f[:notify_before]} type="number" label={gettext("Notify before")} />
              <.search_select
                field={f[:notify_before_unit]}
                label={gettext("Unit")}
                prompt={gettext("—")}
                options={time_unit_options()}
              />
            </div>

            <div class="md:col-span-2">
              <.input field={f[:comments]} type="textarea" label={gettext("Comments")} />
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save renewal")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/renewals"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"renewal" => params} = all, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form, type_value: all["renewal_type"])}
  end

  def handle_event("save", %{"renewal" => params} = all, socket) do
    scope = socket.assigns.current_scope
    type = resolve_type(scope, socket.assigns.types, all["renewal_type"])
    params = Map.put(params, "renewal_type_id", type && type.id)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _renewal} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Renewal saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/renewals")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: form, type_value: all["renewal_type"])
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  # --- find-or-create renewal type ---

  defp resolve_type(_scope, _types, value) when value in [nil, ""], do: nil

  defp resolve_type(scope, types, value) do
    case Enum.find(types, &(&1.id == value)) do
      nil -> VehicleManagement.upsert_renewal_type!(%{name: value}, scope: scope)
      type -> type
    end
  end

  # --- lookups ---

  defp vehicle_options(scope) do
    case VehicleManagement.list_selectable_vehicles(scope: scope) do
      {:ok, vehicles} -> Enum.map(vehicles, &{&1.name, &1.id})
      _ -> []
    end
  end

  defp type_records(scope) do
    VehicleManagement.list_renewal_types!(scope: scope, query: [sort: [name: :asc]])
  end

  defp time_unit_options,
    do:
      Enum.map(
        VehicleManagement.TimeUnit.values(),
        &{&1 |> to_string() |> String.capitalize(), &1}
      )

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
