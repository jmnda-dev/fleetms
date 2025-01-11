defmodule FleetmsWeb.VehicleGeneralReminderLive.FilterFormComponent do
  use FleetmsWeb, :live_component
  import Fleetms.Utils, only: [dates_in_map_to_string: 2]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>
      <.simple_form
        for={@filter_form}
        id="filter-form"
        phx-change="validate"
        phx-submit="apply"
        phx-target={@myself}
        tabindex="-1"
        aria-hidden="true"
      >
        <div class="px-4 space-y-4 md:px-6">
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full" id="vehicle-input" phx-update="ignore">
              <.input
                field={@filter_form[:vehicles]}
                options={@vehicles}
                type="select"
                label="Vehicles"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:vehicles] || @filter_form.data[:vehicles]}
              />
            </div>

            <div class="w-full" id="statuses-input" phx-update="ignore">
              <.input
                field={@filter_form[:statuses]}
                options={Fleetms.Enums.vehicle_assignment_statuses()}
                type="select"
                label="Statuses"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:statuses] || @filter_form.data[:statuses]}
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:start_date_min]}
                type="date"
                label="Start Date Min"
                value={
                  @filter_form.source.changes[:start_date_min] || @filter_form.data[:start_date_min]
                }
              />
            </div>
            <div class="w-full">
              <.input
                field={@filter_form[:start_date_max]}
                type="date"
                label="Start Date Max"
                value={
                  @filter_form.source.changes[:start_date_max] || @filter_form.data[:start_date_max]
                }
              />
            </div>
            <div class="w-full">
              <.input
                field={@filter_form[:end_date_min]}
                type="date"
                label="End Date Min"
                value={@filter_form.source.changes[:end_date_min] || @filter_form.data[:end_date_min]}
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:end_date_max]}
                type="date"
                label="End Date Max"
                value={@filter_form.source.changes[:end_date_max] || @filter_form.data[:end_date_max]}
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:start_mileage_min]}
                type="number"
                label="Start Mileage Min"
                value={
                  @filter_form.source.changes[:start_mileage_min] ||
                    @filter_form.data[:start_mileage_min]
                }
              />
            </div>
            <div class="w-full">
              <.input
                field={@filter_form[:start_mileage_max]}
                type="number"
                label="Start Mileage Max"
                value={
                  @filter_form.source.changes[:start_mileage_max] ||
                    @filter_form.data[:start_mileage_max]
                }
              />
            </div>
            <div class="w-full">
              <.input
                field={@filter_form[:end_mileage_min]}
                type="number"
                label="End Mileage Min"
                value={
                  @filter_form.source.changes[:end_mileage_min] || @filter_form.data[:end_mileage_min]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:end_mileage_max]}
                type="number"
                label="End Mileage Max"
                value={
                  @filter_form.source.changes[:end_mileage_max] || @filter_form.data[:end_mileage_max]
                }
              />
            </div>
          </div>
        </div>
        <!-- Modal footer -->
        <div class="flex items-center p-6 space-x-4 rounded-b dark:border-gray-600">
          <.button type="submit">
            Apply
          </.button>
          <.button type="reset">
            Reset
          </.button>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    filter_form =
      build_filter_changeset(assigns.filter_form_data, %{})
      |> to_form(as: "filter_form")

    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicles =
      Fleetms.VehicleManagement.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    reminder_purposes =
      Fleetms.VehicleManagement.VehicleReminderPurpose.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    socket =
      socket
      |> assign(:filter_form, filter_form)
      |> assign(:vehicles, vehicles)
      |> assign(:reminder_purposes, reminder_purposes)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"filter_form" => form_params}, socket) do
    filter_form =
      build_filter_changeset(socket.assigns.filter_form_data, form_params)
      |> Map.put(:action, :validate)
      |> to_form(as: "filter_form")

    {:noreply, assign(socket, :filter_form, filter_form)}
  end

  @impl true
  def handle_event("apply", %{"filter_form" => form_params}, socket) do
    build_filter_changeset(%{}, form_params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, new_filter_form_data} ->
        new_url_params =
          Map.merge(new_filter_form_data, socket.assigns.paginate_sort_opts)
          |> Map.merge(socket.assigns.search_params)
          |> dates_in_map_to_string([
            :due_date_min,
            :due_date_max
          ])

        {:noreply, push_patch(socket, to: ~p"/vehicle_assignments?#{new_url_params}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :filter_form, changeset |> to_form(as: "filter_form"))}
    end
  end

  def build_filter_changeset(data, submit_params) do
    types = %{
      due_date_min: :date,
      due_date_max: :date,
      time_interval_min: :integer,
      time_interval_max: :integer,
      due_statuses:
        {:array,
         Ecto.ParameterizedType.init(Ecto.Enum,
           values: Fleetms.Enums.general_reminder_statuses()
         )},
      vehicles: {:array, :string}
    }

    {data, types}
    |> Ecto.Changeset.cast(submit_params, Map.keys(types))
    |> Ecto.Changeset.validate_number(:time_interval_min,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:time_interval_max,
      greater_than: -1,
      less_than: 999_999_999
    )
  end
end
