defmodule FleetmsWeb.VehicleLive.Form do
  @moduledoc """
  Create / edit a vehicle.

  The bulk of the fields are an `AshPhoenix.Form` over the vehicle's create/update
  action. Make, model and group are handled alongside it as searchable/creatable
  selects: the chosen (or freshly typed) values are resolved to records on submit
  (find-or-create), and the model select depends on the make — changing the make
  pushes that make's models back to the client.
  """
  use FleetmsWeb, :live_view

  alias AshPhoenix.Form
  alias Fleetms.Format
  alias Fleetms.Tagging
  alias Fleetms.VehicleManagement

  # Shown in the org's distance unit, stored canonically in km.
  @unit_fields %{"mileage" => :distance}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_link: :vehicles, open_sections: ["general"])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    form =
      Form.for_create(VehicleManagement.Vehicle, :create,
        domain: VehicleManagement,
        as: "vehicle",
        scope: scope
      )
      |> Form.add_form(:vehicle_spec)

    socket
    |> assign(page_title: gettext("New vehicle"), vehicle: nil, models: [], tags_value: [])
    |> assign_lookups(scope)
    |> assign(make_value: nil, model_value: nil, group_value: nil)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case VehicleManagement.get_vehicle(id,
           scope: scope,
           load: [:vehicle_spec, :tags, vehicle_model: [:vehicle_make]]
         ) do
      {:ok, vehicle} ->
        form =
          Form.for_update(vehicle, :update,
            domain: VehicleManagement,
            as: "vehicle",
            scope: scope
          )
          |> ensure_spec_form(vehicle)

        make_id = vehicle.vehicle_model && vehicle.vehicle_model.vehicle_make_id

        models =
          if make_id,
            do: VehicleManagement.list_vehicle_models_by_make!(make_id, scope: scope),
            else: []

        socket
        |> assign(
          page_title: gettext("Edit vehicle"),
          vehicle: vehicle,
          models: models,
          tags_value: Enum.map(vehicle.tags, &to_string(&1.name))
        )
        |> assign_lookups(scope)
        |> assign(
          make_value: make_id,
          model_value: vehicle.vehicle_model_id,
          group_value: vehicle.vehicle_group_id
        )
        |> assign(:form, to_form(form))

      {:error, _} ->
        socket
        |> put_flash(:error, gettext("That vehicle could not be found."))
        |> push_navigate(to: ~p"/o/#{org(socket)}/vehicles")
    end
  end

  # Show the spec sub-form whether or not the vehicle already has one.
  defp ensure_spec_form(form, vehicle) do
    if vehicle.vehicle_spec, do: form, else: Form.add_form(form, :vehicle_spec)
  end

  defp assign_lookups(socket, scope) do
    assign(socket,
      makes: VehicleManagement.list_vehicle_makes!(scope: scope, query: [sort: [name: :asc]]),
      groups: VehicleManagement.list_vehicle_groups!(scope: scope, query: [sort: [name: :asc]]),
      tag_options: tag_options(scope)
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
        %{label: gettext("Vehicles"), path: ~p"/o/#{org(assigns)}/vehicles"},
        %{label: @page_title}
      ]} />

      <.header>
        {@page_title}
        <:subtitle>
          {gettext("General information, identification, purchase details and notes.")}
        </:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="vehicle-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6"
      >
        <.accordion open={@open_sections} on_toggle="toggle-section">
          <:section name="general" title={gettext("General information")}>
            <div class="grid gap-4 md:grid-cols-2">
              <.input field={f[:name]} label={gettext("Name")} required />
              <.input field={f[:model_code]} label={gettext("Model code")} />

              <.search_select
                id="vehicle_make"
                name="make"
                value={@make_value}
                create
                dependent_event="make_changed"
                label={gettext("Make")}
                prompt={gettext("Search or add a make…")}
                options={Enum.map(@makes, &{&1.name, &1.id})}
              />
              <.search_select
                id="vehicle_model"
                name="model"
                value={@model_value}
                create
                label={gettext("Model")}
                prompt={gettext("Search or add a model…")}
                options={Enum.map(@models, &{&1.name, &1.id})}
              />

              <.search_select
                id="vehicle_group"
                name="group"
                value={@group_value}
                create
                label={gettext("Group")}
                prompt={gettext("Search or add a group…")}
                options={Enum.map(@groups, &{&1.name, &1.id})}
              />
              <.search_select
                field={f[:type]}
                label={gettext("Type")}
                prompt={gettext("Select a type")}
                options={type_options()}
              />

              <.search_select
                field={f[:category]}
                label={gettext("Category")}
                prompt={gettext("Select a category")}
                options={category_options()}
              />
              <.search_select
                field={f[:body_style]}
                label={gettext("Body style")}
                prompt={gettext("Select a body style")}
                options={body_style_options()}
              />

              <div>
                <.search_select
                  field={f[:status]}
                  label={gettext("Status")}
                  prompt={gettext("Select a status")}
                  options={status_options()}
                  disabled={@live_action == :edit}
                />
                <p :if={@live_action == :edit} class="mt-1 text-xs text-body">
                  {gettext("Use the “Change status” button on the vehicle to change this.")}
                </p>
              </div>
              <.input field={f[:year]} type="number" label={gettext("Year")} />

              <.input field={f[:color]} label={gettext("Color")} />

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
            </div>
          </:section>

          <:section name="identification" title={gettext("Identification")}>
            <div class="grid gap-4 md:grid-cols-2">
              <.input field={f[:license_plate]} label={gettext("License plate")} />
              <.input field={f[:vin]} label={gettext("VIN")} />
              <.input field={f[:chassis_number]} label={gettext("Chassis number")} />
            </div>
          </:section>

          <:section name="purchase" title={gettext("Purchase & usage")}>
            <div class="grid gap-4 md:grid-cols-2">
              <.date_input field={f[:purchase_date]} label={gettext("Purchase date")} />
              <.input field={f[:dealer_name]} label={gettext("Dealer")} />
              <.input field={f[:base_price]} type="number" step="0.01" label={gettext("Base price")} />
              <.input
                field={f[:purchase_price]}
                type="number"
                step="0.01"
                label={gettext("Purchase price")}
              />
              <.input
                field={f[:mileage]}
                value={Format.distance_input(f[:mileage].value, org(assigns))}
                type="number"
                step="0.01"
                label={"#{gettext("Mileage")} (#{Format.distance_unit(org(assigns))})"}
              />
              <.input field={f[:hours]} type="number" step="0.01" label={gettext("Engine hours")} />
            </div>
          </:section>

          <:section name="warranty" title={gettext("Warranty")}>
            <div class="grid gap-4 md:grid-cols-2">
              <.input field={f[:warranty_provider]} label={gettext("Provider")} />
              <.date_input
                field={f[:warranty_expiration_date]}
                label={gettext("Expiration date")}
              />
              <div class="md:col-span-2">
                <.input field={f[:warranty_notes]} type="textarea" label={gettext("Notes")} />
              </div>
            </div>
          </:section>

          <:section name="engine" title={gettext("Engine")}>
            <.inputs_for :let={spec} field={f[:vehicle_spec]}>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={spec[:engine_manufacturer]} label={gettext("Manufacturer")} />
                <.input field={spec[:engine_model]} label={gettext("Model")} />
                <.input field={spec[:engine_serial_number]} label={gettext("Serial number")} />
                <.search_select
                  field={spec[:fuel_type]}
                  label={gettext("Fuel type")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.FuelType)}
                />
                <.search_select
                  field={spec[:aspiration]}
                  label={gettext("Aspiration")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.Aspiration)}
                />
                <.search_select
                  field={spec[:fuel_delivery_type]}
                  label={gettext("Fuel delivery")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.FuelDeliveryType)}
                />
                <.search_select
                  field={spec[:engine_configuration]}
                  label={gettext("Configuration")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.EngineConfiguration)}
                />
                <.search_select
                  field={spec[:valve_train_design]}
                  label={gettext("Valve train")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.ValveTrainDesign)}
                />
                <.search_select
                  field={spec[:cooling_type]}
                  label={gettext("Cooling")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.CoolingType)}
                />
                <.input
                  field={spec[:displacement]}
                  type="number"
                  step="0.01"
                  label={gettext("Displacement (L)")}
                />
                <.input field={spec[:cylinders]} type="number" label={gettext("Cylinders")} />
                <.input
                  field={spec[:valves_per_cylinder]}
                  type="number"
                  label={gettext("Valves / cylinder")}
                />
                <.input
                  field={spec[:cylinder_bore]}
                  type="number"
                  step="0.01"
                  label={gettext("Cylinder bore (mm)")}
                />
                <.input
                  field={spec[:piston_stroke]}
                  type="number"
                  step="0.01"
                  label={gettext("Piston stroke (mm)")}
                />
                <.input field={spec[:compression_ratio]} label={gettext("Compression ratio")} />
                <.input field={spec[:power]} type="number" step="0.01" label={gettext("Power (kW)")} />
                <.input
                  field={spec[:torque]}
                  type="number"
                  step="0.01"
                  label={gettext("Torque (Nm)")}
                />
                <.input
                  field={spec[:oil_capacity]}
                  type="number"
                  step="0.01"
                  label={gettext("Oil capacity (L)")}
                />
                <.input field={spec[:oil_specification]} label={gettext("Oil spec")} />
              </div>
            </.inputs_for>
          </:section>

          <:section name="drivetrain" title={gettext("Drivetrain")}>
            <.inputs_for :let={spec} field={f[:vehicle_spec]}>
              <div class="grid gap-4 md:grid-cols-2">
                <.search_select
                  field={spec[:transmission_type]}
                  label={gettext("Transmission")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.TransmissionType)}
                />
                <.search_select
                  field={spec[:drive_type]}
                  label={gettext("Drive type")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.DriveType)}
                />
                <.input
                  field={spec[:number_of_gears]}
                  type="number"
                  label={gettext("Number of gears")}
                />
                <.input field={spec[:axles]} type="number" label={gettext("Axles")} />
                <.input field={spec[:axle_configuration]} label={gettext("Axle configuration")} />
                <.input
                  field={spec[:transmission_manufacturer]}
                  label={gettext("Transmission manufacturer")}
                />
                <.input field={spec[:transmission_model]} label={gettext("Transmission model")} />
                <.input
                  field={spec[:transmission_serial_number]}
                  label={gettext("Transmission serial number")}
                />
                <.input
                  field={spec[:transmission_oil_capacity]}
                  type="number"
                  step="0.01"
                  label={gettext("Transmission oil capacity (L)")}
                />
                <.input
                  field={spec[:transmission_oil_specification]}
                  label={gettext("Transmission oil spec")}
                />
              </div>
            </.inputs_for>
          </:section>

          <:section name="performance" title={gettext("Performance & emissions")}>
            <.inputs_for :let={spec} field={f[:vehicle_spec]}>
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  field={spec[:fuel_consumption_urban]}
                  type="number"
                  step="0.01"
                  label={gettext("Consumption — urban (L/100km)")}
                />
                <.input
                  field={spec[:fuel_consumption_extra_urban]}
                  type="number"
                  step="0.01"
                  label={gettext("Consumption — extra-urban (L/100km)")}
                />
                <.input
                  field={spec[:fuel_consumption_combined]}
                  type="number"
                  step="0.01"
                  label={gettext("Consumption — combined (L/100km)")}
                />
                <.input
                  field={spec[:co2_emission]}
                  type="number"
                  step="0.01"
                  label={gettext("CO₂ (g/km)")}
                />
                <.input
                  field={spec[:acceleration_0_to_100]}
                  type="number"
                  step="0.01"
                  label={gettext("0–100 km/h (s)")}
                />
                <.input
                  field={spec[:maximum_speed]}
                  type="number"
                  step="0.01"
                  label={gettext("Top speed (km/h)")}
                />
                <.input field={spec[:emission_standard]} label={gettext("Emission standard")} />
              </div>
            </.inputs_for>
          </:section>

          <:section name="chassis" title={gettext("Dimensions, brakes & tyres")}>
            <.inputs_for :let={spec} field={f[:vehicle_spec]}>
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  field={spec[:length]}
                  type="number"
                  step="0.01"
                  label={gettext("Length (mm)")}
                />
                <.input field={spec[:width]} type="number" step="0.01" label={gettext("Width (mm)")} />
                <.input
                  field={spec[:height]}
                  type="number"
                  step="0.01"
                  label={gettext("Height (mm)")}
                />
                <.input
                  field={spec[:wheelbase]}
                  type="number"
                  step="0.01"
                  label={gettext("Wheelbase (mm)")}
                />
                <.search_select
                  field={spec[:brake_system_type]}
                  label={gettext("Brake system")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.BrakeSystemType)}
                />
                <.search_select
                  field={spec[:assisting_system]}
                  label={gettext("Assist system")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.BrakeAssist)}
                />
                <.search_select
                  field={spec[:front_brakes]}
                  label={gettext("Front brakes")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.BrakeType)}
                />
                <.search_select
                  field={spec[:rear_brakes]}
                  label={gettext("Rear brakes")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.BrakeType)}
                />
                <.input field={spec[:front_tire_spec]} label={gettext("Front tyres")} />
                <.input field={spec[:rear_tire_spec]} label={gettext("Rear tyres")} />
                <.search_select
                  field={spec[:steering_side]}
                  label={gettext("Steering side")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.SteeringSide)}
                />
                <.search_select
                  field={spec[:steering_type]}
                  label={gettext("Steering type")}
                  prompt={gettext("Select")}
                  options={enum_options(VehicleManagement.SteeringType)}
                />
              </div>
            </.inputs_for>
          </:section>

          <:section name="capacities" title={gettext("Weights & capacities")}>
            <.inputs_for :let={spec} field={f[:vehicle_spec]}>
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  field={spec[:gross_weight]}
                  type="number"
                  step="0.01"
                  label={gettext("Gross weight (kg)")}
                />
                <.input
                  field={spec[:net_weight]}
                  type="number"
                  step="0.01"
                  label={gettext("Net weight (kg)")}
                />
                <.input
                  field={spec[:max_payload]}
                  type="number"
                  step="0.01"
                  label={gettext("Max payload (kg)")}
                />
                <.input
                  field={spec[:towing_capacity]}
                  type="number"
                  step="0.01"
                  label={gettext("Towing capacity (kg)")}
                />
                <.input
                  field={spec[:fuel_tank_capacity]}
                  type="number"
                  step="0.01"
                  label={gettext("Fuel tank (L)")}
                />
              </div>
            </.inputs_for>
          </:section>

          <:section name="notes" title={gettext("Notes")}>
            <.rich_text field={f[:notes]} label={gettext("Notes")} />
          </:section>
        </.accordion>

        <div class="mt-6 flex items-center gap-3">
          <.button type="submit" phx-disable-with={gettext("Saving…")}>
            {gettext("Save vehicle")}
          </.button>
          <.button variant="secondary" navigate={~p"/o/#{org(assigns)}/vehicles"}>
            {gettext("Cancel")}
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("toggle-section", %{"section" => name}, socket) do
    open = socket.assigns.open_sections

    open = if name in open, do: List.delete(open, name), else: [name | open]
    {:noreply, assign(socket, :open_sections, open)}
  end

  def handle_event("validate", %{"vehicle" => params} = all, socket) do
    form = Form.validate(socket.assigns.form, params)

    {:noreply,
     assign(socket,
       form: form,
       make_value: all["make"],
       model_value: all["model"],
       group_value: all["group"]
     )}
  end

  def handle_event("make_changed", %{"value" => value}, socket) do
    scope = socket.assigns.current_scope

    models =
      case existing_by_id(socket.assigns.makes, value) do
        nil -> []
        make -> VehicleManagement.list_vehicle_models_by_make!(make.id, scope: scope)
      end

    options = Enum.map(models, &%{value: &1.id, text: &1.name})

    {:noreply,
     socket
     |> assign(models: models, make_value: value, model_value: nil)
     |> push_event("tomselect:options:vehicle_model", %{options: options, value: nil})}
  end

  def handle_event("save", %{"vehicle" => params} = all, socket) do
    scope = socket.assigns.current_scope
    make = resolve_make(scope, socket.assigns.makes, all["make"])
    model = resolve_model(scope, socket.assigns.models, make, all["model"])
    group = resolve_group(scope, socket.assigns.groups, all["group"])

    params =
      params
      |> Format.to_canonical_params(@unit_fields, org(socket))
      |> Map.put("vehicle_model_id", model && model.id)
      |> Map.put("vehicle_group_id", group && group.id)

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, vehicle} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Vehicle saved."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/vehicles/#{vehicle.id}")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, gettext("Please fix the errors below."))}
    end
  end

  # --- find-or-create resolution for make/model/group ---

  defp resolve_make(_scope, _makes, value) when value in [nil, ""], do: nil

  defp resolve_make(scope, makes, value) do
    case existing_by_id(makes, value) do
      nil -> VehicleManagement.upsert_vehicle_make!(%{name: value}, scope: scope)
      make -> make
    end
  end

  defp resolve_model(_scope, _models, nil, _value), do: nil
  defp resolve_model(_scope, _models, _make, value) when value in [nil, ""], do: nil

  defp resolve_model(scope, models, make, value) do
    case existing_by_id(models, value) do
      nil ->
        VehicleManagement.upsert_vehicle_model!(%{name: value, vehicle_make_id: make.id},
          scope: scope
        )

      model ->
        model
    end
  end

  defp resolve_group(_scope, _groups, value) when value in [nil, ""], do: nil

  defp resolve_group(scope, groups, value) do
    case existing_by_id(groups, value) do
      nil -> VehicleManagement.create_vehicle_group!(%{name: value}, scope: scope)
      group -> group
    end
  end

  defp existing_by_id(records, value), do: Enum.find(records, &(&1.id == value))

  # --- options ---

  defp type_options, do: enum_options(VehicleManagement.VehicleType)
  defp category_options, do: enum_options(VehicleManagement.VehicleCategory)
  defp body_style_options, do: enum_options(VehicleManagement.VehicleBodyStyle)
  defp status_options, do: enum_options(VehicleManagement.VehicleStatus)

  defp enum_options(module), do: Enum.map(module.values(), &{to_string(&1), &1})

  # Existing tag names for autocomplete; value == name so picked and typed entries alike
  # are names the action can relate-or-create.
  defp tag_options(scope) do
    Tagging.list_tags!(scope: scope) |> Enum.map(&{to_string(&1.name), to_string(&1.name)})
  end

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization
end
