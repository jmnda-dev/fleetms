defmodule FleetmsWeb.FuelHistoryLive.FilterFormComponent do
  use FleetmsWeb, :live_component
  import Fleetms.Utils, only: [dates_in_map_to_string: 2]

  alias Fleetms.Accounts

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

            <div class="w-full" id="refueled_by-select" phx-update="ignore">
              <.input
                field={@filter_form[:refueled_by]}
                options={@users}
                type="select"
                label="Refueled By"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:refueled_by] || @filter_form.data[:refueled_by]}
              />
            </div>

            <div class="w-full" id="fuel_types-select" phx-update="ignore">
              <.input
                field={@filter_form[:fuel_types]}
                options={Fleetms.Enums.fuel_tracking_fuel_types()}
                type="select"
                label="Fuel Types"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={@filter_form.source.changes[:fuel_types] || @filter_form.data[:fuel_types]}
              />
            </div>

            <div class="w-full" id="payment_methods-select" phx-update="ignore">
              <.input
                field={@filter_form[:payment_methods]}
                options={Fleetms.Enums.fuel_tracking_payment_methods()}
                type="select"
                label="Payment Methods"
                multiple
                phx-hook="select2JS"
                style="width: 100%;"
                value={
                  @filter_form.source.changes[:payment_methods] || @filter_form.data[:payment_methods]
                }
              />
            </div>
          </div>
          <div class="grid gap-6 md:grid-cols-2">
            <div class="w-full">
              <.input
                field={@filter_form[:odometer_reading_min]}
                type="number"
                label="Odometer Reading Min"
                value={
                  @filter_form.source.changes[:odometer_reading_min] ||
                    @filter_form.data[:odometer_reading_min]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:odometer_reading_max]}
                type="number"
                label="Odometer Reading Max"
                value={
                  @filter_form.source.changes[:odometer_reading_max] ||
                    @filter_form.data[:odometer_reading_max]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:refuel_date_from]}
                type="date"
                label="Refuel Date From"
                value={
                  @filter_form.source.changes[:refuel_date_from] ||
                    @filter_form.data[:refuel_date_from]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:refuel_date_to]}
                type="date"
                label="Refuel Date To"
                value={
                  @filter_form.source.changes[:refuel_date_to] ||
                    @filter_form.data[:refuel_date_to]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:refuel_quantity_min]}
                type="number"
                label="Refuel Quantity Min"
                value={
                  @filter_form.source.changes[:refuel_quantity_min] ||
                    @filter_form.data[:refuel_quantity_min]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:refuel_quantity_max]}
                type="number"
                label="Refuel Quantity Max"
                value={
                  @filter_form.source.changes[:refuel_quantity_max] ||
                    @filter_form.data[:refuel_quantity_max]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:refuel_cost_min]}
                type="number"
                label="Refuel Cost Min"
                value={
                  @filter_form.source.changes[:refuel_cost_min] ||
                    @filter_form.data[:refuel_cost_min]
                }
              />
            </div>

            <div class="w-full">
              <.input
                field={@filter_form[:refuel_cost_max]}
                type="number"
                label="Refuel Cost Max"
                value={
                  @filter_form.source.changes[:refuel_cost_max] ||
                    @filter_form.data[:refuel_cost_max]
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
    %{tenant: tenant, current_user: actor} = socket.assigns

    filter_form =
      build_filter_changeset(assigns.filter_form_data, %{})
      |> to_form(as: "filter_form")

    vehicles =
      Fleetms.Vehicles.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    users =
      Accounts.get_all_users!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.user_profile.full_name, &1.id})

    socket =
      socket
      |> assign(:filter_form, filter_form)
      |> assign(:vehicles, vehicles)
      |> assign(:users, users)

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
            :refuel_date_from,
            :refuel_date_to
          ])
          |> Map.merge(socket.assigns.paginate_sort_opts)
          |> Map.merge(socket.assigns.search_params)

        {:noreply, push_patch(socket, to: ~p"/fuel_histories?#{new_url_params}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :filter_form, changeset |> to_form(as: "filter_form"))}
    end
  end

  def build_filter_changeset(data, submit_params) do
    types = %{
      odometer_reading_min: :integer,
      odometer_reading_max: :integer,
      refuel_date_from: :date,
      refuel_date_to: :date,
      refuel_quantity_min: :integer,
      refuel_quantity_max: :integer,
      refuel_cost_min: :integer,
      refuel_cost_max: :integer,
      vehicles: {:array, :string},
      refueled_by: {:array, :string},
      fuel_types:
        {:array,
         Ecto.ParameterizedType.init(Ecto.Enum, values: Fleetms.Enums.fuel_tracking_fuel_types())},
      payment_methods:
        {:array,
         Ecto.ParameterizedType.init(Ecto.Enum,
           values: Fleetms.Enums.fuel_tracking_payment_methods()
         )}
    }

    {data, types}
    |> Ecto.Changeset.cast(submit_params, Map.keys(types))
    |> Ecto.Changeset.validate_number(:odometer_reading_min,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:odometer_reading_max,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:refuel_quantity_min,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:refuel_quantity_max,
      greater_than: -1,
      less_than: 999_999_999
    )
    |> Ecto.Changeset.validate_number(:refuel_cost_min, greater_than: -1, less_than: 999_999_999)
    |> Ecto.Changeset.validate_number(:refuel_cost_max, greater_than: -1, less_than: 999_999_999)
  end
end
