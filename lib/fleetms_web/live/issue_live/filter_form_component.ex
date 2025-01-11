defmodule FleetmsWeb.IssueLive.FilterFormComponent do
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
            <div class="w-full">
              <.input
                field={@filter_form[:vehicle_id]}
                options={[{:All, :All}] ++ @vehicles}
                type="select"
                label="Vehicle"
                value={@filter_form.source.changes[:vehicle_id] || @filter_form.data[:vehicle_id]}
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:date_reported_from]}
                type="date"
                label="Date Reported From"
                value={
                  @filter_form.source.changes[:date_reported_from] ||
                    @filter_form.data[:date_reported_from]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:date_reported_to]}
                type="date"
                label="Date Reported To"
                value={
                  @filter_form.source.changes[:date_reported_to] ||
                    @filter_form.data[:date_reported_to]
                }
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:due_date_from]}
                type="date"
                label="Due Date From"
                value={
                  @filter_form.source.changes[:due_date_from] || @filter_form.data[:due_date_from]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:due_date_to]}
                type="date"
                label="Due Date To"
                value={@filter_form.source.changes[:due_date_to] || @filter_form.data[:due_date_to]}
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:mileage_min]}
                type="number"
                label="Mileage Min"
                value={@filter_form.source.changes[:mileage_min] || @filter_form.data[:mileage_min]}
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:mileage_max]}
                type="number"
                label="Mileage Max"
                value={@filter_form.source.changes[:mileage_max] || @filter_form.data[:mileage_max]}
              />
            </div>
          </div>

          <div class="grid gap-6 md:grid-cols-2">
            <.input
              field={@filter_form[:status]}
              type="select"
              options={[:All] ++ Fleetms.Enums.issue_statuses()}
              label="Status"
              value={@filter_form.source.changes[:status] || @filter_form.data[:status]}
            />
            <.input
              field={@filter_form[:priority]}
              type="select"
              options={[:All] ++ Fleetms.Enums.issue_priority()}
              label="Priority"
              value={@filter_form.source.changes[:priority] || @filter_form.data[:priority]}
            />
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
    %{tenant: tenant, current_user: actor} = socket.assigns

    filter_form =
      build_filter_changeset(assigns.filter_form_data, %{})
      |> to_form(as: "filter_form")

    vehicles =
      Fleetms.VehicleManagement.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    socket =
      socket
      |> assign(:filter_form, filter_form)
      |> assign(:vehicles, vehicles)

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
    build_filter_changeset(socket.assigns.filter_form_data, form_params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, new_filter_form_data} ->
        new_url_params =
          new_filter_form_data
          |> dates_in_map_to_string([
            :date_reported_from,
            :date_reported_to,
            :due_date_from,
            :due_date_to
          ])
          |> Map.merge(socket.assigns.paginate_sort_opts)
          |> Map.merge(socket.assigns.search_params)

        {:noreply, push_patch(socket, to: ~p"/issues?#{new_url_params}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :filter_form, changeset |> to_form(as: "filter_form"))}
    end
  end

  def build_filter_changeset(data, submit_params) do
    types = %{
      mileage_min: :integer,
      mileage_max: :integer,
      date_reported_to: :date,
      date_reported_from: :date,
      due_date_to: :date,
      due_date_from: :date,
      priority:
        Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.issue_priority() ++ [:All]),
      status:
        Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.issue_statuses() ++ [:All]),
      vehicle_id: :string
    }

    {data, types}
    |> Ecto.Changeset.cast(submit_params, Map.keys(types))
    |> Ecto.Changeset.validate_number(:mileage_min, greater_than: -1, less_than: 999_999_999)
    |> Ecto.Changeset.validate_number(:mileage_max, greater_than: -1, less_than: 999_999_999)
  end
end
