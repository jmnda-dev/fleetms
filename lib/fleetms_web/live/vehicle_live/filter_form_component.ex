defmodule FleetmsWeb.VehicleLive.FilterFormComponent do
  use FleetmsWeb, :live_component

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
                field={@filter_form[:vehicle_make]}
                options={[:All] ++ @vehicle_makes}
                type="select"
                label="Make"
                phx-change="vehicle_make_selected"
                value={@filter_form.source.changes[:vehicle_make] || @filter_form.data[:vehicle_make]}
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:model]}
                options={[:All] ++ @vehicle_models}
                type="select"
                label="Model"
                value={@filter_form.source.changes[:model] || @filter_form.data[:model]}
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:year_from]}
                type="number"
                label="Year From"
                value={@filter_form.source.changes[:year_from] || @filter_form.data[:year_from]}
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:year_to]}
                type="number"
                label="Year To"
                value={@filter_form.source.changes[:year_to] || @filter_form.data[:year_to]}
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
              options={[:All] ++ Fleetms.Enums.vehicle_statuses()}
              label="Status"
              value={@filter_form.source.changes[:status] || @filter_form.data[:status]}
            />
            <.input
              field={@filter_form[:type]}
              type="select"
              options={[:All] ++ Fleetms.Enums.vehicle_types()}
              label="Type"
              value={@filter_form.source.changes[:type] || @filter_form.data[:type]}
            />
            <.input
              field={@filter_form[:category]}
              type="select"
              options={[:All] ++ Fleetms.Enums.vehicle_categories()}
              label="Category"
              value={@filter_form.source.changes[:category] || @filter_form.data[:category]}
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

    vehicle_makes =
      Fleetms.Vehicles.VehicleMake.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.name})

    socket =
      socket
      |> assign(:filter_form, filter_form)
      |> assign(:vehicle_makes, vehicle_makes)
      |> maybe_fetch_vehicle_models()

    {:ok, socket}
  end

  @impl true
  def handle_event("vehicle_make_selected", %{"filter_form" => form_params}, socket) do
    IO.inspect(form_params, label: "FORM PARAMS")
    %{tenant: tenant, current_user: actor} = socket.assigns

    case form_params["vehicle_make"] do
      nil ->
        {:noreply, socket}

      "All" ->
        {:noreply, assign(socket, :vehicle_models, [])}

      vehicle_make ->
        vehicle_models =
          Fleetms.Vehicles.VehicleModel.list_by_vehicle_make!(vehicle_make,
            tenant: tenant,
            actor: actor
          )
          |> Enum.map(&{&1.name, &1.name})

        {:noreply, assign(socket, :vehicle_models, vehicle_models)}
    end
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

        {:noreply, push_patch(socket, to: ~p"/vehicles?#{new_url_params}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :filter_form, changeset |> to_form(as: "filter_form"))}
    end
  end

  def build_filter_changeset(data, submit_params) do
    types = %{
      mileage_min: :integer,
      mileage_max: :integer,
      year_from: :integer,
      year_to: :integer,
      type:
        Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.vehicle_types() ++ [:All]),
      status:
        Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.vehicle_statuses() ++ [:All]),
      category:
        Ecto.ParameterizedType.init(Ecto.Enum,
          values: Fleetms.Enums.vehicle_categories() ++ [:All]
        ),
      vehicle_make: :string,
      model: :string
    }

    {data, types}
    |> Ecto.Changeset.cast(submit_params, Map.keys(types))
    |> Ecto.Changeset.validate_number(:year_from, greater_than: 1969, less_than: 2030)
    |> Ecto.Changeset.validate_number(:year_to, greater_than: 1969, less_than: 2030)
    |> Ecto.Changeset.validate_number(:mileage_min, greater_than: -1, less_than: 999_999_999)
    |> Ecto.Changeset.validate_number(:mileage_max, greater_than: -1, less_than: 999_999_999)
  end

  defp maybe_fetch_vehicle_models(%{assigns: %{filter_form_data: filter_form_data}} = socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    case filter_form_data[:vehicle_make] do
      vehicle_make when vehicle_make in ["All", nil] ->
        assign(socket, :vehicle_models, [])

      vehicle_make ->
        vehicle_models =
          Fleetms.Vehicles.VehicleModel.list_by_vehicle_make!(vehicle_make,
            tenant: tenant,
            actor: actor
          )
          |> Enum.map(&{&1.name, &1.name})

        assign(socket, :vehicle_models, vehicle_models)
    end
  end
end
