defmodule FleetmsWeb.VehicleLive.FilterFormComponent do
  use FleetmsWeb, :live_component
  alias Fleetms.VehicleManagement
  alias VehicleManagement.{VehicleMake, VehicleModel, VehicleListFilter}

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="vehicle-filters-drawer"
      data-clone-attributes="true"
      class="fixed top-0 left-0 z-40 w-full h-screen max-w-sm p-4 overflow-y-auto transition-transform -translate-x-full bg-white dark:bg-gray-800"
      tabindex="-1"
      aria-labelledby="drawer-label"
    >
      <h5
        id="drawer-label"
        class="inline-flex items-center mb-4 text-base font-semibold text-gray-500 uppercase dark:text-gray-400"
      >
        Filters
      </h5>
      <button
        id="drawer-dismiss-button"
        type="button"
        data-drawer-dismiss="vehicle-filters-drawer"
        aria-controls="vehicle-filters-drawer"
        class="text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm p-1.5 absolute top-2.5 right-2.5 inline-flex items-center dark:hover:bg-gray-600 dark:hover:text-white"
      >
        <svg
          aria-hidden="true"
          class="w-5 h-5"
          fill="currentColor"
          viewBox="0 0 20 20"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            fill-rule="evenodd"
            d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
            clip-rule="evenodd"
          >
          </path>
        </svg>
        <span class="sr-only">Close menu</span>
      </button>

      <div class="flex flex-col justify-between flex-1">
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
            <div class="space-y-4">
              <div class="grid gap-6 md:grid-cols-2">
                <div class="w-full">
                  <.input
                    field={@filter_form[:make]}
                    options={@vehicle_makes}
                    type="select"
                    label="Make"
                    phx-change="load_vehicle_models"
                    prompt="All"
                  />
                </div>

                <div class="w-full">
                  <.input
                    field={@filter_form[:model]}
                    options={@vehicle_models}
                    type="select"
                    label="Model"
                    prompt="All"
                  />
                </div>
              </div>
              <div class="grid gap-6 md:grid-cols-2">
                <div class="w-full">
                  <.input field={@filter_form[:year_min]} type="number" label="Year Min" />
                </div>

                <div class="w-full">
                  <.input field={@filter_form[:year_max]} type="number" label="Year Max" />
                </div>
              </div>
              <div class="grid gap-6 md:grid-cols-2">
                <div class="w-full">
                  <.input field={@filter_form[:mileage_min]} type="number" label="Mileage Min" />
                </div>

                <div class="w-full">
                  <.input field={@filter_form[:mileage_max]} type="number" label="Mileage Max" />
                </div>
              </div>
              <div id="vehicle-statuses-input" phx-update="ignore">
                <.input
                  field={@filter_form[:statuses]}
                  type="select"
                  multiple
                  options={Fleetms.Enums.vehicle_statuses()}
                  label="Status"
                  phx-hook="select2JS"
                />
              </div>
              <div id="vehicle-types-input" phx-update="ignore">
                <.input
                  field={@filter_form[:types]}
                  type="select"
                  multiple
                  options={Fleetms.Enums.vehicle_types()}
                  label="Type"
                  phx-hook="select2JS"
                />
              </div>
              <div id="vehicle-categories-input" phx-update="ignore">
                <.input
                  field={@filter_form[:categories]}
                  type="select"
                  options={Fleetms.Enums.vehicle_categories()}
                  multiple
                  label="Category"
                  phx-hook="select2JS"
                />
              </div>
            </div>
            <!-- Modal footer -->
            <div class="flex items-center p-6 space-x-4 rounded-b dark:border-gray-600">
              <.button type="submit" phx-click={JS.dispatch("click", to: "#drawer-dismiss-button")}>
                Apply
              </.button>
              <.button type="button" phx-click="reset_form" phx-target={@myself}>
                Reset
              </.button>
            </div>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    %{tenant: tenant, current_user: actor, applied_filters: applied_filters} = socket.assigns

    filter_form =
      AshPhoenix.Form.for_create(VehicleListFilter, :validate, as: "filter_form")
      |> AshPhoenix.Form.set_data(applied_filters)
      |> to_form()

    vehicle_makes =
      VehicleMake.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.name})

    socket =
      socket
      |> assign(:filter_form, filter_form)
      |> assign(:vehicle_makes, vehicle_makes)
      |> maybe_fetch_vehicle_models()

    {:ok, socket}
  end

  @impl true
  def handle_event("load_vehicle_models", %{"filter_form" => form_params}, socket) do
    %{tenant: tenant, current_user: actor, filter_form: filter_form} = socket.assigns

    vehicle_models =
      case form_params["make"] do
        value when value in [nil, ""] ->
          []

        vehicle_make ->
          VehicleModel.list_by_vehicle_make!(vehicle_make,
            tenant: tenant,
            actor: actor
          )
          |> Enum.map(&{&1.name, &1.id})
      end

    socket =
      assign(socket, :vehicle_models, vehicle_models)
      |> assign(:filter_form, AshPhoenix.Form.validate(filter_form, form_params))

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"filter_form" => form_params}, socket) do
    filter_form = AshPhoenix.Form.validate(socket.assigns.filter_form, form_params)

    {:noreply, assign(socket, :filter_form, filter_form)}
  end

  @impl true
  def handle_event("apply", %{"filter_form" => form_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.filter_form, params: form_params) do
      {:ok, %VehicleListFilter{} = list_filters} ->
        query_params = VehicleListFilter.to_params!(list_filters)
        {:noreply, push_patch(socket, to: ~p"/vehicles?#{query_params}")}

      {:error, filter_form} ->
        {:noreply, assign(socket, :filter_form, filter_form)}
    end
  end

  @impl true
  def handle_event("reset_form", _params, socket) do
    socket =
      update(socket, :filter_form, fn _filter_form ->
        AshPhoenix.Form.for_create(VehicleListFilter, :validate, as: "filter_form")
        |> AshPhoenix.Form.set_data(%{})
        |> to_form()
      end)

    {:noreply, socket}
  end

  defp maybe_fetch_vehicle_models(%{assigns: %{applied_filters: applied_filters}} = socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    case applied_filters[:make] do
      nil ->
        assign(socket, :vehicle_models, [])

      make ->
        vehicle_models =
          VehicleModel.list_by_vehicle_make!(make,
            tenant: tenant,
            actor: actor
          )
          |> Enum.map(&{&1.name, &1.id})

        assign(socket, :vehicle_models, vehicle_models)
    end
  end
end
