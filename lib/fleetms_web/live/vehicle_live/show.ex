defmodule FleetmsWeb.VehicleLive.Show do
  @moduledoc """
  Vehicle detail page: a header summary plus tabbed Details / Photos / Documents.

  Photos and documents are uploaded straight from this page via the resources'
  `:upload` actions — photos are processed into a display image + thumbnail,
  documents stored as-is. The headline image shown in lists and the header is
  kept in sync with the first photo.
  """
  use FleetmsWeb, :live_view

  alias Fleetms.Format
  alias Fleetms.FuelManagement
  alias Fleetms.Scope
  alias Fleetms.VehicleManagement
  alias Fleetms.VehicleManagement.MeterReadings
  alias FleetmsWeb.VehicleLive.StatusPresenter

  @loads [
    :full_name,
    :vehicle_group,
    :vehicle_spec,
    :tags,
    :paper_trail_versions,
    photos: [],
    documents: [],
    vehicle_model: [:vehicle_make]
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(active_tab: "details", active_link: :vehicles, fuel_stats: nil)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 10,
       max_file_size: 10_000_000
     )
     |> allow_upload(:documents,
       accept: ~w(.pdf .doc .docx .xls .xlsx .csv .txt .png .jpg .jpeg),
       max_entries: 10,
       max_file_size: 20_000_000
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope

    case VehicleManagement.get_vehicle(id, scope: scope, load: @loads) do
      {:ok, vehicle} ->
        qr_url = url(~p"/o/#{scope.organization}/vehicles/#{vehicle.id}")

        {:noreply,
         socket
         |> assign(:vehicle, vehicle)
         |> assign(:page_title, vehicle.full_name)
         |> assign(:qr_url, qr_url)
         |> assign(:qr_svg, Fleetms.QRCode.svg(qr_url))
         |> assign(:meter_readings, MeterReadings.for_vehicle(scope, vehicle.id))
         |> assign(:members, FleetmsWeb.ActivityLog.member_names(scope))
         |> assign(:status_modal_vehicle, nil)
         |> assign(:fuel_stats, nil)
         |> assign(:reminders, nil)
         |> assign(:issues, nil)
         |> assign(:assignments, nil)
         |> assign(:can_update, Scope.has_permission?(scope, :update_vehicle))
         |> assign(:can_view_fuel, Scope.has_permission?(scope, :view_fuel_entries))
         |> assign(:can_create_fuel, Scope.has_permission?(scope, :create_fuel_entry))
         |> assign(:can_view_reminders, Scope.has_permission?(scope, :view_service_reminders))
         |> assign(
           :can_create_reminder,
           Scope.has_permission?(scope, :create_service_reminder)
         )
         |> assign(:can_view_issues, Scope.has_permission?(scope, :view_issues))
         |> assign(:can_create_issue, Scope.has_permission?(scope, :create_issue))
         |> assign(:can_view_assignments, Scope.has_permission?(scope, :view_assignments))}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("That vehicle could not be found."))
         |> push_navigate(to: ~p"/o/#{org(socket)}/vehicles")}
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
        %{label: gettext("Vehicles"), path: ~p"/o/#{org(assigns)}/vehicles"},
        %{label: @vehicle.full_name}
      ]} />

      <%!-- Header summary --%>
      <div class="mt-4 flex flex-col gap-4 rounded-base border border-default bg-white p-4 shadow-sm dark:bg-gray-800 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <img
            :if={storage_url(@vehicle.primary_thumbnail_key)}
            src={storage_url(@vehicle.primary_thumbnail_key)}
            alt={@vehicle.name}
            class="h-16 w-16 rounded-md object-cover"
          />
          <span
            :if={is_nil(@vehicle.primary_thumbnail_key)}
            class="flex h-16 w-16 items-center justify-center rounded-md bg-gray-100 text-2xl text-gray-400 dark:bg-gray-700"
          >
            <.icon name="fa-truck" />
          </span>
          <div>
            <h1 class="text-xl font-bold text-heading">{@vehicle.full_name}</h1>
            <p class="mt-1 text-sm text-body">
              {gettext("Status:")}
              <StatusPresenter.status_badge status={@vehicle.status} />
            </p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <.button :if={@can_update} variant="secondary" phx-click="open_status">
            <.icon name="fa-arrows-rotate" class="me-2" /> {gettext("Change status")}
          </.button>
          <.button :if={@can_update} navigate={~p"/o/#{org(assigns)}/vehicles/#{@vehicle.id}/edit"}>
            <.icon name="fa-pen-to-square" class="me-2" /> {gettext("Edit")}
          </.button>
        </div>
      </div>

      <StatusPresenter.status_modal vehicle={@status_modal_vehicle} />

      <div class="mt-4 rounded-base border border-default bg-white px-4 shadow-sm dark:bg-gray-800">
        <.tabs active={@active_tab} on_select="select-tab">
          <:tab name="details" label={gettext("Details")} icon="fa-list-check">
            <.list>
              <:item title={gettext("Name")}>{@vehicle.name}</:item>
              <:item title={gettext("Make")}>{present(make_name(@vehicle))}</:item>
              <:item title={gettext("Model")}>{present(model_name(@vehicle))}</:item>
              <:item title={gettext("Group")}>{present(group_name(@vehicle))}</:item>
              <:item title={gettext("Type")}>{present(@vehicle.type)}</:item>
              <:item title={gettext("Category")}>{present(@vehicle.category)}</:item>
              <:item title={gettext("Body style")}>{present(@vehicle.body_style)}</:item>
              <:item title={gettext("Year")}>{present(@vehicle.year)}</:item>
              <:item title={gettext("Color")}>{present(@vehicle.color)}</:item>
              <:item title={gettext("License plate")}>{present(@vehicle.license_plate)}</:item>
              <:item title={gettext("VIN")}>{present(@vehicle.vin)}</:item>
              <:item title={gettext("Chassis number")}>{present(@vehicle.chassis_number)}</:item>
              <:item title={gettext("Mileage")}>
                {Format.distance(@vehicle.mileage, org(assigns))}
              </:item>
              <:item title={gettext("Engine hours")}>{present(@vehicle.hours)}</:item>
              <:item :if={@vehicle.tags != []} title={gettext("Tags")}>
                <.tag_list tags={@vehicle.tags} />
              </:item>
              <:item title={gettext("Purchase date")}>
                {Format.date(@vehicle.purchase_date, org(assigns))}
              </:item>
              <:item title={gettext("Purchase price")}>{present(@vehicle.purchase_price)}</:item>
              <:item title={gettext("Dealer")}>{present(@vehicle.dealer_name)}</:item>
            </.list>

            <div
              :if={warranty_present?(@vehicle)}
              class="mt-6 rounded-base border border-default p-4"
            >
              <h3 class="mb-3 flex items-center gap-2 text-sm font-semibold uppercase text-heading">
                <.icon name="fa-shield-halved" class="text-body" /> {gettext("Warranty")}
                <span
                  :if={warranty_expired?(@vehicle)}
                  class="rounded bg-red-100 px-2 py-0.5 text-xs font-medium normal-case text-red-800 dark:bg-red-900 dark:text-red-200"
                >
                  {gettext("Expired")}
                </span>
              </h3>
              <.list>
                <:item title={gettext("Provider")}>{present(@vehicle.warranty_provider)}</:item>
                <:item title={gettext("Expires")}>
                  {Format.date(@vehicle.warranty_expiration_date, org(assigns))}
                </:item>
                <:item :if={@vehicle.warranty_notes} title={gettext("Notes")}>
                  {@vehicle.warranty_notes}
                </:item>
              </.list>
            </div>

            <div :if={@vehicle.notes} class="mt-6">
              <h3 class="mb-2 text-sm font-semibold uppercase text-heading">{gettext("Notes")}</h3>
              <div class="format dark:format-invert max-w-none">{raw(@vehicle.notes)}</div>
            </div>
          </:tab>

          <:tab name="specs" label={gettext("Specifications")} icon="fa-gauge-high">
            <div :if={spec_present?(@vehicle.vehicle_spec)} class="space-y-6">
              <.spec_group
                title={gettext("Engine")}
                spec={@vehicle.vehicle_spec}
                fields={[
                  {gettext("Manufacturer"), :engine_manufacturer},
                  {gettext("Model"), :engine_model},
                  {gettext("Serial number"), :engine_serial_number},
                  {gettext("Fuel type"), :fuel_type},
                  {gettext("Aspiration"), :aspiration},
                  {gettext("Fuel delivery"), :fuel_delivery_type},
                  {gettext("Configuration"), :engine_configuration},
                  {gettext("Valve train"), :valve_train_design},
                  {gettext("Cooling"), :cooling_type},
                  {gettext("Displacement (L)"), :displacement},
                  {gettext("Cylinders"), :cylinders},
                  {gettext("Valves / cylinder"), :valves_per_cylinder},
                  {gettext("Cylinder bore (mm)"), :cylinder_bore},
                  {gettext("Piston stroke (mm)"), :piston_stroke},
                  {gettext("Compression ratio"), :compression_ratio},
                  {gettext("Power (kW)"), :power},
                  {gettext("Torque (Nm)"), :torque},
                  {gettext("Oil capacity (L)"), :oil_capacity},
                  {gettext("Oil spec"), :oil_specification}
                ]}
              />

              <.spec_group
                title={gettext("Drivetrain")}
                spec={@vehicle.vehicle_spec}
                fields={[
                  {gettext("Transmission"), :transmission_type},
                  {gettext("Drive type"), :drive_type},
                  {gettext("Number of gears"), :number_of_gears},
                  {gettext("Axles"), :axles},
                  {gettext("Axle configuration"), :axle_configuration},
                  {gettext("Transmission manufacturer"), :transmission_manufacturer},
                  {gettext("Transmission model"), :transmission_model},
                  {gettext("Transmission serial number"), :transmission_serial_number},
                  {gettext("Transmission oil capacity (L)"), :transmission_oil_capacity},
                  {gettext("Transmission oil spec"), :transmission_oil_specification}
                ]}
              />

              <.spec_group
                title={gettext("Performance & emissions")}
                spec={@vehicle.vehicle_spec}
                fields={[
                  {gettext("Consumption — urban (L/100km)"), :fuel_consumption_urban},
                  {gettext("Consumption — extra-urban (L/100km)"), :fuel_consumption_extra_urban},
                  {gettext("Consumption — combined (L/100km)"), :fuel_consumption_combined},
                  {gettext("CO₂ (g/km)"), :co2_emission},
                  {gettext("0–100 km/h (s)"), :acceleration_0_to_100},
                  {gettext("Top speed (km/h)"), :maximum_speed},
                  {gettext("Emission standard"), :emission_standard}
                ]}
              />

              <.spec_group
                title={gettext("Dimensions, brakes & tyres")}
                spec={@vehicle.vehicle_spec}
                fields={[
                  {gettext("Length (mm)"), :length},
                  {gettext("Width (mm)"), :width},
                  {gettext("Height (mm)"), :height},
                  {gettext("Wheelbase (mm)"), :wheelbase},
                  {gettext("Brake system"), :brake_system_type},
                  {gettext("Assist system"), :assisting_system},
                  {gettext("Front brakes"), :front_brakes},
                  {gettext("Rear brakes"), :rear_brakes},
                  {gettext("Front tyres"), :front_tire_spec},
                  {gettext("Rear tyres"), :rear_tire_spec},
                  {gettext("Steering side"), :steering_side},
                  {gettext("Steering type"), :steering_type}
                ]}
              />

              <.spec_group
                title={gettext("Weights & capacities")}
                spec={@vehicle.vehicle_spec}
                fields={[
                  {gettext("Gross weight (kg)"), :gross_weight},
                  {gettext("Net weight (kg)"), :net_weight},
                  {gettext("Max payload (kg)"), :max_payload},
                  {gettext("Towing capacity (kg)"), :towing_capacity},
                  {gettext("Fuel tank (L)"), :fuel_tank_capacity}
                ]}
              />
            </div>
            <p :if={not spec_present?(@vehicle.vehicle_spec)} class="text-body">
              {gettext("No specifications recorded.")}
            </p>
          </:tab>

          <:tab name="photos" label={gettext("Photos")} icon="fa-image">
            <div
              :if={@vehicle.photos != []}
              class="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4"
            >
              <div :for={photo <- @vehicle.photos} class="group relative">
                <a href={storage_url(photo.image_key)} target="_blank" rel="noopener">
                  <img
                    src={storage_url(photo.thumbnail_key)}
                    alt={photo.caption || @vehicle.name}
                    class="h-32 w-full rounded-lg object-cover"
                  />
                </a>
                <button
                  :if={@can_update}
                  type="button"
                  phx-click="delete-photo"
                  phx-value-id={photo.id}
                  data-confirm={gettext("Delete this photo?")}
                  class="absolute right-2 top-2 hidden h-8 w-8 items-center justify-center rounded-full bg-white/90 text-fg-danger shadow group-hover:flex dark:bg-gray-900/90"
                >
                  <.icon name="fa-trash" class="text-sm" />
                </button>
              </div>
            </div>
            <p :if={@vehicle.photos == []} class="text-body">{gettext("No photos yet.")}</p>

            <.upload_panel
              :if={@can_update}
              upload={@uploads.photos}
              submit="save-photos"
              cancel="cancel-photo"
              upload_error={&upload_error/1}
              label={gettext("Upload photos")}
              hint={gettext("PNG, JPG or WEBP up to 10MB")}
            />
          </:tab>

          <:tab name="documents" label={gettext("Documents")} icon="fa-file-lines">
            <ul :if={@vehicle.documents != []} class="divide-y divide-default">
              <li :for={doc <- @vehicle.documents} class="flex items-center gap-3 py-3">
                <span class="flex h-10 w-10 items-center justify-center rounded-lg bg-brand-softer text-fg-brand">
                  <.icon name="fa-file" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate font-medium text-heading">{doc.filename}</p>
                  <p class="text-sm text-body">
                    {present(doc.content_type)} · {humanize_bytes(doc.byte_size)}
                  </p>
                </div>
                <.link
                  href={storage_url(doc.storage_key)}
                  target="_blank"
                  rel="noopener"
                  class="rounded p-2 text-body hover:bg-gray-100 hover:text-heading dark:hover:bg-gray-700"
                >
                  <.icon name="fa-download" />
                </.link>
                <button
                  :if={@can_update}
                  type="button"
                  phx-click="delete-document"
                  phx-value-id={doc.id}
                  data-confirm={gettext("Delete %{name}?", name: doc.filename)}
                  class="rounded p-2 text-fg-danger hover:bg-danger-soft"
                >
                  <.icon name="fa-trash" />
                </button>
              </li>
            </ul>
            <p :if={@vehicle.documents == []} class="text-body">{gettext("No documents yet.")}</p>

            <.upload_panel
              :if={@can_update}
              upload={@uploads.documents}
              submit="save-documents"
              cancel="cancel-document"
              upload_error={&upload_error/1}
              label={gettext("Upload documents")}
              hint={gettext("PDF, Office, images or text up to 20MB")}
            />
          </:tab>

          <:tab :if={@can_view_fuel} name="fuel" label={gettext("Fuel")} icon="fa-gas-pump">
            <div :if={@fuel_stats} class="space-y-6">
              <div class="flex items-center justify-between">
                <h3 class="text-sm font-semibold uppercase text-heading">
                  {gettext("Fuel economy")}
                </h3>
                <.button
                  :if={@can_create_fuel}
                  size="sm"
                  navigate={~p"/o/#{org(assigns)}/fuel/new?#{%{vehicle_id: @vehicle.id}}"}
                >
                  <.icon name="fa-plus" class="me-2" /> {gettext("New fuel entry")}
                </.button>
              </div>

              <p :if={@fuel_stats.summary.entry_count == 0} class="py-8 text-center text-body">
                {gettext("No fuel entries for this vehicle yet.")}
              </p>

              <div :if={@fuel_stats.summary.entry_count > 0} class="space-y-6">
                <.fuel_summary summary={@fuel_stats.summary} />
                <.fuel_volume_chart data={@fuel_stats.monthly_volume} />

                <div class="overflow-x-auto">
                  <table class="w-full text-left text-sm text-body">
                    <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
                      <tr>
                        <th class="px-4 py-3 font-semibold">{gettext("Date")}</th>
                        <th class="px-4 py-3 font-semibold">{gettext("Odometer")}</th>
                        <th class="px-4 py-3 font-semibold">{gettext("Distance")}</th>
                        <th class="px-4 py-3 font-semibold">{gettext("Quantity")}</th>
                        <th class="px-4 py-3 font-semibold">{gettext("Economy")}</th>
                        <th class="px-4 py-3 text-right font-semibold">{gettext("Cost")}</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={row <- @fuel_stats.rows} class="border-t border-default">
                        <td class="whitespace-nowrap px-4 py-3">
                          {Format.date(row.entry.refueled_at, org(assigns))}
                        </td>
                        <td class="whitespace-nowrap px-4 py-3">{fmt_num(row.entry.odometer)}</td>
                        <td class="whitespace-nowrap px-4 py-3">{fmt_num(row.distance)}</td>
                        <td class="whitespace-nowrap px-4 py-3">{fmt_num(row.entry.quantity)}</td>
                        <td class="whitespace-nowrap px-4 py-3">{fmt_economy(row.economy)}</td>
                        <td class="whitespace-nowrap px-4 py-3 text-right font-medium text-heading">
                          {fmt_money(row.entry.cost)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </:tab>

          <:tab
            :if={@can_view_reminders}
            name="reminders"
            label={gettext("Service reminders")}
            icon="fa-bell"
          >
            <div class="mb-4 flex justify-end">
              <.button
                :if={@can_create_reminder}
                size="sm"
                navigate={~p"/o/#{org(assigns)}/service-reminders/new?#{%{vehicle_id: @vehicle.id}}"}
              >
                <.icon name="fa-plus" class="me-2" /> {gettext("New reminder")}
              </.button>
            </div>

            <p :if={@reminders == []} class="py-8 text-center text-body">
              {gettext("No service reminders for this vehicle yet.")}
            </p>

            <div :if={@reminders != []} class="overflow-x-auto">
              <table class="w-full text-left text-sm text-body">
                <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
                  <tr>
                    <th class="px-4 py-3 font-semibold">{gettext("Service task")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Next due mileage")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Next due date")}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={r <- @reminders} class="border-t border-default">
                    <td class="px-4 py-3">{r.service_task_name}</td>
                    <td class="px-4 py-3">
                      <FleetmsWeb.ServiceReminderLive.Index.due_badge status={r.due_status} />
                    </td>
                    <td class="px-4 py-3">{reminder_mileage(r)}</td>
                    <td class="px-4 py-3">{reminder_date(r)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </:tab>

          <:tab
            :if={@can_view_issues}
            name="issues"
            label={gettext("Issues")}
            icon="fa-circle-exclamation"
          >
            <div class="mb-4 flex justify-end">
              <.button
                :if={@can_create_issue}
                size="sm"
                navigate={~p"/o/#{org(assigns)}/issues/new?#{%{vehicle_id: @vehicle.id}}"}
              >
                <.icon name="fa-plus" class="me-2" /> {gettext("New issue")}
              </.button>
            </div>

            <p :if={@issues == []} class="py-8 text-center text-body">
              {gettext("No issues for this vehicle yet.")}
            </p>

            <div :if={@issues != []} class="overflow-x-auto">
              <table class="w-full text-left text-sm text-body">
                <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
                  <tr>
                    <th class="px-4 py-3 font-semibold">{gettext("#")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Title")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Priority")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :for={issue <- @issues}
                    phx-click={JS.navigate(~p"/o/#{org(assigns)}/issues/#{issue.id}")}
                    class="cursor-pointer border-t border-default hover:bg-gray-50 dark:hover:bg-gray-700"
                  >
                    <td class="px-4 py-3 font-medium text-heading">#{issue.issue_number}</td>
                    <td class="px-4 py-3">{issue.title}</td>
                    <td class="px-4 py-3">{issue.priority}</td>
                    <td class="px-4 py-3">
                      <.badge color={issue_status_color(issue.status)}>
                        {humanize_status(issue.status)}
                      </.badge>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </:tab>

          <:tab
            :if={@can_view_assignments}
            name="assignments"
            label={gettext("Assignments")}
            icon="fa-id-card"
          >
            <p :if={@assignments == []} class="py-8 text-center text-body">
              {gettext("This vehicle has never been assigned to anyone.")}
            </p>

            <div :if={@assignments not in [nil, []]} class="overflow-x-auto">
              <table class="w-full text-left text-sm text-body">
                <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
                  <tr>
                    <th class="px-4 py-3 font-semibold">{gettext("Driver")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("From")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("To")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Status")}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={assignment <- @assignments} class="border-t border-default">
                    <td class="px-4 py-3 font-medium text-heading">
                      {assignee_name(assignment)}
                    </td>
                    <td class="whitespace-nowrap px-4 py-3">
                      {Format.datetime(assignment.start_datetime, org(assigns))}
                    </td>
                    <td class="whitespace-nowrap px-4 py-3">
                      {until(assignment.end_datetime, org(assigns))}
                    </td>
                    <td class="px-4 py-3">
                      <.badge color={assignment_status_color(assignment.status)}>
                        {assignment.status}
                      </.badge>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </:tab>

          <:tab name="comments" label={gettext("Comments")} icon="fa-comments">
            <.live_component
              module={FleetmsWeb.CommentsSection}
              id={"comments-#{@vehicle.id}"}
              scope={@current_scope}
              parent_key={:vehicle_id}
              parent_id={@vehicle.id}
            />
          </:tab>

          <:tab name="history" label={gettext("History")} icon="fa-clock-rotate-left">
            <FleetmsWeb.ActivityLog.timeline
              kind={:vehicle}
              versions={@vehicle.paper_trail_versions}
              members={@members}
            />
          </:tab>

          <:tab name="meter" label={gettext("Meter history")} icon="fa-gauge">
            <div class="py-2">
              <p class="mb-4 text-sm text-body">
                {gettext("Odometer readings captured on fuel entries, issues and work orders.")}
              </p>

              <table :if={@meter_readings != []} class="w-full text-left text-sm text-body">
                <thead class="bg-gray-50 text-xs uppercase text-heading dark:bg-gray-700">
                  <tr>
                    <th class="px-4 py-3 font-semibold">{gettext("Reading")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Date")}</th>
                    <th class="px-4 py-3 font-semibold">{gettext("Source")}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={reading <- @meter_readings} class="border-t border-default">
                    <td class="whitespace-nowrap px-4 py-3 font-medium text-heading">
                      {Format.distance(reading.value, org(assigns))}
                    </td>
                    <td class="whitespace-nowrap px-4 py-3">
                      {Format.date(reading.date, org(assigns))}
                    </td>
                    <td class="px-4 py-3">
                      <span class="flex items-center gap-1.5">
                        <.icon name={meter_source_icon(reading.source)} class="text-xs text-gray-400" />
                        {reading.label}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>

              <.empty_state
                :if={@meter_readings == []}
                icon="fa-gauge"
                title={gettext("No meter readings yet")}
                message={gettext("Log a fuel entry, issue or work order with an odometer reading.")}
              />
            </div>
          </:tab>

          <:tab name="qr" label={gettext("QR code")} icon="fa-qrcode">
            <div class="flex flex-col items-center gap-4 py-8 text-center">
              <div id="vehicle-qr" class="rounded-base border border-default bg-white p-4">
                {raw(@qr_svg)}
                <p class="mt-2 text-sm font-semibold text-gray-900">{@vehicle.full_name}</p>
                <p :if={@vehicle.license_plate} class="text-xs text-gray-500">
                  {@vehicle.license_plate}
                </p>
              </div>
              <p class="max-w-md text-sm text-body">
                {gettext(
                  "Print this and stick it on the vehicle. Scanning it opens this page for anyone signed in."
                )}
              </p>
              <p class="break-all text-xs text-gray-400">{@qr_url}</p>
              <.button variant="secondary" id="print-vehicle-qr" phx-hook="PrintButton">
                <.icon name="fa-print" class="me-2" /> {gettext("Print")}
              </.button>
            </div>
          </:tab>
        </.tabs>
      </div>
    </Layouts.app>
    """
  end

  attr :upload, :any, required: true
  attr :submit, :string, required: true
  attr :cancel, :string, required: true
  attr :upload_error, :any, required: true
  attr :label, :string, required: true
  attr :hint, :string, required: true

  defp upload_panel(assigns) do
    ~H"""
    <form
      phx-submit={@submit}
      phx-change="validate-upload"
      id={"#{@upload.ref}-form"}
      class="mt-6 border-t border-default pt-4"
    >
      <label
        phx-drop-target={@upload.ref}
        class="flex cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-default-medium bg-gray-50 p-6 text-center hover:bg-gray-100 dark:bg-gray-700 dark:hover:bg-gray-600"
      >
        <.icon name="fa-cloud-arrow-up" class="mb-2 text-2xl text-body" />
        <span class="text-sm text-body">
          <span class="font-semibold text-heading">{gettext("Click to upload")}</span>
          {gettext("or drag and drop")}
        </span>
        <span class="mt-1 text-xs text-body">{@hint}</span>
        <.live_file_input upload={@upload} aria-label={gettext("Upload file")} class="hidden" />
      </label>

      <p :for={err <- upload_errors(@upload)} class="mt-2 text-sm text-fg-danger">
        {@upload_error.(err)}
      </p>

      <div :for={entry <- @upload.entries} class="mt-3 flex items-center gap-3">
        <.live_img_preview
          :if={String.starts_with?(entry.client_type, "image/")}
          entry={entry}
          class="h-12 w-12 rounded object-cover"
        />
        <span
          :if={not String.starts_with?(entry.client_type, "image/")}
          class="flex h-12 w-12 items-center justify-center rounded bg-gray-100 text-gray-400 dark:bg-gray-700"
        >
          <.icon name="fa-file" />
        </span>
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm text-heading">{entry.client_name}</p>
          <progress value={entry.progress} max="100" class="h-1.5 w-full">{entry.progress}%</progress>
          <p :for={err <- upload_errors(@upload, entry)} class="text-xs text-fg-danger">
            {@upload_error.(err)}
          </p>
        </div>
        <button
          type="button"
          phx-click={@cancel}
          phx-value-ref={entry.ref}
          class="rounded p-1.5 text-body hover:text-heading"
          aria-label={gettext("Cancel")}
        >
          <.icon name="fa-xmark" />
        </button>
      </div>

      <.button :if={@upload.entries != []} type="submit" class="mt-4">{@label}</.button>
    </form>
    """
  end

  attr :summary, :map, required: true

  defp fuel_summary(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <.stat_card
          label={gettext("Avg economy")}
          value={fmt_economy(@summary.avg_economy)}
          icon="fa-gauge-high"
        />
        <.stat_card
          label={gettext("Distance")}
          value={fmt_num(@summary.total_distance)}
          icon="fa-road"
        />
        <.stat_card
          label={gettext("Volume")}
          value={fmt_num(@summary.total_volume)}
          icon="fa-gas-pump"
        />
        <.stat_card label={gettext("Entries")} value={@summary.entry_count} icon="fa-list-ul" />
      </div>

      <div :if={@summary.spend != []} class="flex flex-wrap items-center gap-2">
        <span class="text-xs font-semibold uppercase text-body">{gettext("Total spend")}</span>
        <span
          :for={money <- @summary.spend}
          class="rounded-full bg-brand-softer px-3 py-1 text-sm font-medium text-fg-brand"
        >
          {fmt_money(money)}
        </span>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="flex items-center gap-3 rounded-base border border-default bg-gray-50 p-4 dark:bg-gray-700/40">
      <span class="flex h-10 w-10 items-center justify-center rounded-lg bg-brand-softer text-fg-brand">
        <.icon name={@icon} />
      </span>
      <div>
        <p class="text-xs uppercase text-body">{@label}</p>
        <p class="text-lg font-semibold text-heading">{@value}</p>
      </div>
    </div>
    """
  end

  # Compact monthly-volume bar chart, rendered as self-contained SVG (no JS): bars
  # use `currentColor` so the theme accent applies in light and dark.
  attr :data, :list, required: true

  defp fuel_volume_chart(assigns) do
    assigns = assign(assigns, :bars, chart_bars(assigns.data))

    ~H"""
    <div :if={@bars != []}>
      <h4 class="mb-2 text-xs font-semibold uppercase text-body">{gettext("Monthly volume")}</h4>
      <svg
        viewBox="0 0 480 170"
        class="h-44 w-full text-primary-500"
        role="img"
        aria-label={gettext("Monthly fuel volume")}
      >
        <g :for={bar <- @bars}>
          <rect x={bar.x} y={bar.y} width={bar.w} height={bar.h} rx="2" fill="currentColor" />
          <text x={bar.cx} y="166" text-anchor="middle" class="fill-current text-body text-[9px]">
            {bar.label}
          </text>
        </g>
      </svg>
    </div>
    """
  end

  # Scale the (last 12) months into 480x140 bars, leaving room for axis labels.
  defp chart_bars([]), do: []

  defp chart_bars(data) do
    data = Enum.take(data, -12)
    count = length(data)
    slot = 480 / count
    bar_w = slot * 0.6

    max_v =
      data
      |> Enum.map(&Decimal.to_float(&1.volume))
      |> Enum.max()
      |> then(&if(&1 <= 0, do: 1.0, else: &1))

    data
    |> Enum.with_index()
    |> Enum.map(fn {item, i} ->
      h = Decimal.to_float(item.volume) / max_v * 130
      x = i * slot + (slot - bar_w) / 2

      %{
        x: Float.round(x, 1),
        y: Float.round(140 - h, 1),
        w: Float.round(bar_w, 1),
        h: Float.round(h, 1),
        cx: Float.round(x + bar_w / 2, 1),
        label: String.slice(item.label, 0, 3)
      }
    end)
  end

  defp fmt_num(nil), do: "—"
  # `:normal` avoids scientific notation (normalize turns 12000 into 1.2E+4 otherwise).
  defp fmt_num(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp fmt_economy(nil), do: "—"
  defp fmt_economy(%Decimal{} = d), do: "#{Decimal.to_string(d, :normal)} /unit"

  defp fmt_money(%Money{} = money), do: Money.to_string!(money)
  defp fmt_money(_), do: "—"

  # An open-ended assignment (no end) is still ongoing.
  defp until(nil, _org), do: gettext("Ongoing")
  defp until(%DateTime{} = dt, org), do: Format.datetime(dt, org)

  defp assignee_name(%{assignee: %{profile: %{first_name: first, last_name: last}} = user}) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> to_string(user.email)
      name -> name
    end
  end

  defp assignee_name(%{assignee: %{email: email}}), do: to_string(email)

  # Assigned to a driver rather than a member — the name lives on the driver.
  defp assignee_name(%{driver: %{first_name: first, last_name: last}}) do
    case [first, last] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> "—"
      name -> name
    end
  end

  defp assignee_name(_), do: "—"

  defp assignment_status_color("Upcoming"), do: "info"
  defp assignment_status_color("In-progress"), do: "success"
  defp assignment_status_color(_), do: "gray"

  @impl true
  def handle_event("select-tab", %{"tab" => "fuel"}, socket) do
    {:noreply, socket |> maybe_load_fuel() |> assign(:active_tab, "fuel")}
  end

  def handle_event("select-tab", %{"tab" => "reminders"}, socket) do
    {:noreply, socket |> maybe_load_reminders() |> assign(:active_tab, "reminders")}
  end

  def handle_event("select-tab", %{"tab" => "issues"}, socket) do
    {:noreply, socket |> maybe_load_issues() |> assign(:active_tab, "issues")}
  end

  def handle_event("select-tab", %{"tab" => "assignments"}, socket) do
    {:noreply, socket |> maybe_load_assignments() |> assign(:active_tab, "assignments")}
  end

  def handle_event("select-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("open_status", _params, socket) do
    {:noreply, assign(socket, :status_modal_vehicle, socket.assigns.vehicle)}
  end

  def handle_event("close_status", _params, socket) do
    {:noreply, assign(socket, :status_modal_vehicle, nil)}
  end

  def handle_event("set_status", %{"status" => status}, socket) do
    scope = socket.assigns.current_scope

    case VehicleManagement.update_vehicle_status(socket.assigns.vehicle, %{status: status},
           scope: scope
         ) do
      {:ok, vehicle} ->
        {:noreply,
         socket
         |> assign(
           vehicle: %{socket.assigns.vehicle | status: vehicle.status},
           status_modal_vehicle: nil
         )
         |> put_flash(:info, gettext("Status updated."))}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:status_modal_vehicle, nil)
         |> put_flash(:error, gettext("Could not update the status."))}
    end
  end

  def handle_event("validate-upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("cancel-document", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :documents, ref)}
  end

  def handle_event("save-photos", _params, socket) do
    scope = socket.assigns.current_scope
    vehicle = socket.assigns.vehicle

    results =
      consume_uploaded_entries(socket, :photos, fn %{path: path}, _entry ->
        {:ok,
         VehicleManagement.upload_vehicle_photo(
           %{vehicle_id: vehicle.id, source_path: path},
           scope: scope
         )}
      end)

    {:noreply, finish_upload(socket, results, gettext("Photos uploaded."))}
  end

  def handle_event("save-documents", _params, socket) do
    scope = socket.assigns.current_scope
    vehicle = socket.assigns.vehicle

    results =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        {:ok,
         VehicleManagement.upload_vehicle_document(
           %{
             vehicle_id: vehicle.id,
             source_path: path,
             filename: entry.client_name,
             content_type: entry.client_type,
             byte_size: entry.client_size
           },
           scope: scope
         )}
      end)

    {:noreply, finish_upload(socket, results, gettext("Documents uploaded."))}
  end

  def handle_event("delete-photo", %{"id" => id}, socket) do
    delete_child(
      socket,
      socket.assigns.vehicle.photos,
      id,
      &VehicleManagement.delete_vehicle_photo/2
    )
  end

  def handle_event("delete-document", %{"id" => id}, socket) do
    delete_child(
      socket,
      socket.assigns.vehicle.documents,
      id,
      &VehicleManagement.delete_vehicle_document/2
    )
  end

  defp finish_upload(socket, results, success_message) do
    if Enum.any?(results, &match?({:error, _}, &1)) do
      socket |> refresh() |> put_flash(:error, gettext("Some files could not be saved."))
    else
      socket |> refresh() |> put_flash(:info, success_message)
    end
  end

  defp delete_child(socket, collection, id, destroy_fun) do
    scope = socket.assigns.current_scope

    case Enum.find(collection, &(&1.id == id)) do
      nil -> {:noreply, socket}
      record -> destroy_fun.(record, scope: scope) && {:noreply, refresh(socket)}
    end
  end

  # Reloads the vehicle and keeps its headline photo in sync with the first photo.
  defp refresh(socket) do
    scope = socket.assigns.current_scope
    id = socket.assigns.vehicle.id

    vehicle = VehicleManagement.get_vehicle!(id, scope: scope, load: @loads)
    sync_primary(vehicle, scope)

    assign(socket, :vehicle, VehicleManagement.get_vehicle!(id, scope: scope, load: @loads))
  end

  defp sync_primary(vehicle, scope) do
    {image, thumb} =
      case vehicle.photos do
        [first | _] -> {first.image_key, first.thumbnail_key}
        [] -> {nil, nil}
      end

    if {vehicle.primary_image_key, vehicle.primary_thumbnail_key} != {image, thumb} do
      VehicleManagement.update_vehicle!(
        vehicle,
        %{primary_image_key: image, primary_thumbnail_key: thumb},
        scope: scope
      )
    end
  end

  # --- display helpers ---

  defp storage_url(nil), do: nil
  defp storage_url(key), do: Fleetms.Storage.url(key)

  defp warranty_present?(vehicle) do
    vehicle.warranty_provider not in [nil, ""] or
      not is_nil(vehicle.warranty_expiration_date) or
      vehicle.warranty_notes not in [nil, ""]
  end

  defp warranty_expired?(%{warranty_expiration_date: nil}), do: false

  defp warranty_expired?(%{warranty_expiration_date: date}),
    do: Date.compare(date, Date.utc_today()) == :lt

  defp meter_source_icon(:fuel), do: "fa-gas-pump"
  defp meter_source_icon(:issue), do: "fa-triangle-exclamation"
  defp meter_source_icon(:work_order), do: "fa-screwdriver-wrench"

  defp make_name(%{vehicle_model: %{vehicle_make: %{name: name}}}), do: name
  defp make_name(_), do: nil

  defp model_name(%{vehicle_model: %{name: name}}), do: name
  defp model_name(_), do: nil

  defp group_name(%{vehicle_group: %{name: name}}), do: name
  defp group_name(_), do: nil

  defp present(nil), do: "—"
  defp present(""), do: "—"
  defp present(value), do: value

  defp humanize_bytes(nil), do: ""
  defp humanize_bytes(bytes) when bytes < 1_024, do: "#{bytes} B"
  defp humanize_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp humanize_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp upload_error(:too_large), do: gettext("File is too large.")
  defp upload_error(:too_many_files), do: gettext("Too many files.")
  defp upload_error(:not_accepted), do: gettext("That file type isn't allowed.")
  defp upload_error(_), do: gettext("Invalid file.")

  # Renders a titled spec group, listing only the fields that actually have a
  # value so partially-filled (or empty) specs don't render rows of "—".
  attr :title, :string, required: true
  attr :spec, :map, required: true
  attr :fields, :list, required: true

  defp spec_group(assigns) do
    filled =
      Enum.filter(assigns.fields, fn {_label, key} -> not blank?(Map.get(assigns.spec, key)) end)

    assigns = assign(assigns, :filled, filled)

    ~H"""
    <div :if={@filled != []}>
      <h3 class="mb-2 text-sm font-semibold uppercase text-heading">{@title}</h3>
      <.list>
        <:item :for={{label, key} <- @filled} title={label}>{Map.get(@spec, key)}</:item>
      </.list>
    </div>
    """
  end

  # Whether the spec carries any user-entered data (ignores ids/timestamps/rels).
  defp spec_present?(nil), do: false

  defp spec_present?(spec) do
    meta = [:id, :vehicle_id, :vehicle, :inserted_at, :updated_at, :__meta__, :__struct__]

    spec
    |> Map.from_struct()
    |> Enum.any?(fn {key, value} -> key not in meta and not blank?(value) end)
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(%Ash.NotLoaded{}), do: true
  defp blank?(_), do: false

  defp org(%Phoenix.LiveView.Socket{} = socket), do: socket.assigns.current_scope.organization
  defp org(assigns), do: assigns.current_scope.organization

  # Load the vehicle's fuel economy once, the first time the tab is opened.
  defp maybe_load_fuel(%{assigns: %{fuel_stats: nil, can_view_fuel: true}} = socket) do
    stats =
      FuelManagement.Economy.for_vehicle(socket.assigns.vehicle.id,
        scope: socket.assigns.current_scope
      )

    assign(socket, :fuel_stats, stats)
  end

  defp maybe_load_fuel(socket), do: socket

  # Load the vehicle's service reminders once, the first time the tab is opened.
  defp maybe_load_reminders(%{assigns: %{reminders: nil, can_view_reminders: true}} = socket) do
    result =
      Fleetms.Maintenance.list_vehicle_service_reminders!(socket.assigns.vehicle.id,
        scope: socket.assigns.current_scope
      )

    assign(socket, :reminders, page_results(result))
  end

  defp maybe_load_reminders(socket), do: socket

  defp maybe_load_issues(%{assigns: %{issues: nil, can_view_issues: true}} = socket) do
    result =
      Fleetms.VehicleIssues.list_vehicle_issues!(socket.assigns.vehicle.id,
        scope: socket.assigns.current_scope
      )

    assign(socket, :issues, page_results(result))
  end

  defp maybe_load_issues(socket), do: socket

  defp maybe_load_assignments(
         %{assigns: %{assignments: nil, can_view_assignments: true}} = socket
       ) do
    assignments =
      Fleetms.VehicleManagement.list_assignments_for_vehicle!(socket.assigns.vehicle.id,
        scope: socket.assigns.current_scope
      )

    assign(socket, :assignments, assignments)
  end

  defp maybe_load_assignments(socket), do: socket

  defp issue_status_color(:open), do: "info"
  defp issue_status_color(:resolved), do: "success"
  defp issue_status_color(:closed), do: "gray"

  defp humanize_status(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  defp page_results(%{results: results}), do: results
  defp page_results(list) when is_list(list), do: list

  defp reminder_mileage(%{next_due_mileage: nil}), do: "—"
  defp reminder_mileage(%{next_due_mileage: m}), do: Decimal.to_string(m, :normal)

  defp reminder_date(%{next_due_date: nil}), do: "—"
  defp reminder_date(%{next_due_date: d}), do: Calendar.strftime(d, "%Y-%m-%d")
end
