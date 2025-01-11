defmodule FleetmsWeb.ServiceReminderLive.FilterFormComponent do
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
            <div class="w-full" id="vehicles-select" phx-update="ignore">
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

            <div class="w-full" id="service_groups-select" phx-update="ignore">
              <.input
                field={@filter_form[:service_groups]}
                options={@service_groups}
                type="select"
                label="Service Groups"
                multiple
                phx-hook="select2JS"
                value={
                  @filter_form.source.changes[:service_groups] || @filter_form.data[:service_groups]
                }
              />
            </div>
            <div class="w-full" id="service_tasks-select" phx-update="ignore">
              <.input
                field={@filter_form[:service_tasks]}
                options={@service_tasks}
                type="select"
                label="Service Tasks"
                multiple
                phx-hook="select2JS"
                value={
                  @filter_form.source.changes[:service_tasks] || @filter_form.data[:service_tasks]
                }
              />
            </div>
            <div class="w-full" id="due_status-select" phx-update="ignore">
              <.input
                field={@filter_form[:due_statuses]}
                options={Fleetms.Enums.service_reminder_statuses()}
                type="select"
                label="Due Status"
                multiple
                phx-hook="select2JS"
                value={@filter_form.source.changes[:due_statuses] || @filter_form.data[:due_statuses]}
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:next_due_date_from]}
                type="date"
                label="Next Due Date From"
                value={
                  @filter_form.source.changes[:next_due_date_from] ||
                    @filter_form.data[:next_due_date_from]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:next_due_date_to]}
                type="date"
                label="Next Due Date To"
                value={
                  @filter_form.source.changes[:next_due_date_to] ||
                    @filter_form.data[:next_due_date_to]
                }
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:mileage_interval_min]}
                type="number"
                label="Mileage Interval Min"
                value={
                  @filter_form.source.changes[:mileage_interval_min] ||
                    @filter_form.data[:mileage_interval_min]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:mileage_interval_max]}
                type="number"
                label="Mileage Interval Max"
                value={
                  @filter_form.source.changes[:mileage_interval_max] ||
                    @filter_form.data[:mileage_interval_max]
                }
              />
            </div>
          </div>

          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:time_interval_min]}
                type="number"
                label="Time Interval Min"
                value={
                  @filter_form.source.changes[:time_interval_min] ||
                    @filter_form.data[:time_interval_min]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:time_interval_max]}
                type="number"
                label="Time Interval Max"
                value={
                  @filter_form.source.changes[:time_interval_max] ||
                    @filter_form.data[:time_interval_max]
                }
              />
            </div>
            <div class="w-full">
              <.input
                field={@filter_form[:time_interval_unit]}
                type="select"
                options={[:All] ++ Fleetms.Enums.time_units()}
                prompt=""
                label="Time Interval Unit"
                value={
                  @filter_form.source.changes[:time_interval_unit] ||
                    @filter_form.data[:time_interval_unit]
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

    service_tasks =
      Fleetms.VehicleMaintenance.ServiceTask.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    service_groups =
      Fleetms.VehicleMaintenance.ServiceGroup.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    socket =
      socket
      |> assign(:filter_form, filter_form)
      |> assign(:vehicles, vehicles)
      |> assign(:service_tasks, service_tasks)
      |> assign(:service_groups, service_groups)

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
          new_filter_form_data
          |> dates_in_map_to_string([
            :next_due_date_from,
            :next_due_date_to
          ])
          |> Map.merge(socket.assigns.paginate_sort_opts)
          |> Map.merge(socket.assigns.search_params)

        {:noreply, push_patch(socket, to: ~p"/service_reminders?#{new_url_params}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :filter_form, changeset |> to_form(as: "filter_form"))}
    end
  end

  def build_filter_changeset(data, submit_params) do
    types = %{
      mileage_interval_min: :integer,
      mileage_interval_max: :integer,
      mileage_next_due_min: :integer,
      mileage_next_due_max: :integer,
      time_interval_min: :integer,
      time_interval_max: :integer,
      time_interval_unit:
        Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.time_units() ++ [:All]),
      next_due_date_to: :date,
      next_due_date_from: :date,
      due_statuses:
        {:array,
         Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.service_reminder_statuses())},
      vehicles: {:array, :string},
      service_groups: {:array, :string},
      service_tasks: {:array, :string}
    }

    {data, types}
    |> Ecto.Changeset.cast(submit_params, Map.keys(types))
    |> Ecto.Changeset.validate_number(:mileage_interval_min,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:mileage_interval_max,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:mileage_next_due_min,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:mileage_next_due_min,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:time_interval_min,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:time_interval_max,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> validate_next_due_date()
  end

  defp validate_next_due_date(changeset) do
    next_due_date_from = Ecto.Changeset.get_change(changeset, :next_due_date_from)
    next_due_date_to = Ecto.Changeset.get_change(changeset, :next_due_date_to)

    if not is_nil(next_due_date_to) and next_due_date_from > next_due_date_to do
      Ecto.Changeset.add_error(
        changeset,
        :next_due_date_from,
        "Next Due Date From must be less that Next Due Date To"
      )
    else
      changeset
    end
  end
end
