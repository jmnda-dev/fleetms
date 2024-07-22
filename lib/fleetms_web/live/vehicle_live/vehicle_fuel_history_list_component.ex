defmodule FleetmsWeb.VehicleLive.VehicleFuelHistoryListComponent do
  use FleetmsWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@loading} class="flex justify-center">
        <.spinner class="text-center" />
      </div>

      <.table_2
        :if={not @loading}
        id="fuel_histories"
        rows={@streams.vehicle_fuel_histories}
        row_click={fn {_id, fuel_history} -> JS.navigate(~p"/fuel_histories/#{fuel_history}") end}
      >
        <:col :let={{_id, fuel_history}} label="Odometer Reading">
          <.badge kind={:primary} label={fuel_history.odometer_reading} />
        </:col>
        <:col :let={{_id, fuel_history}} label="Refuel Date">
          <time id="refuel-datetime" class="invisible" phx-hook="LocalTime">
            <%= fuel_history.refuel_datetime %>
          </time>
        </:col>
        <:col :let={{_id, fuel_history}} label="Refuel By">
          <.badge
            :if={not is_nil(fuel_history.refueled_by)}
            kind={:info}
            label={fuel_history.refueled_by.user_profile.full_name}
          />
        </:col>
        <:col :let={{_id, fuel_history}} label="Fuel Type">
          <.badge kind={:primary} label={fuel_history.fuel_type} />
        </:col>
        <:col :let={{_id, fuel_history}} label="Quantity">
          <%= fuel_history.refuel_quantity %>
        </:col>
        <:col :let={{_id, fuel_history}} label="Cost"><%= fuel_history.refuel_cost %></:col>
        <:col :let={{_id, fuel_history}} label="Location">
          <%= fuel_history.refuel_location %>
        </:col>
        <:col :let={{_id, fuel_history}} label="Payment Method">
          <%= fuel_history.payment_method %>
        </:col>
      </.table_2>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream(:vehicle_fuel_histories, [])
     |> assign(:loading, true)}
  end

  @impl true
  def update(%{vehicle: vehicle} = assigns, socket) do
    socket =
      assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    socket =
      socket
      |> start_async(:get_vehicle_fuel_histories, fn ->
        load_vehicle_fuel_histories(vehicle, tenant, actor)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_async(
        :get_vehicle_fuel_histories,
        {:ok, %Ash.Page.Offset{results: results} = _result},
        socket
      ) do
    socket =
      assign(socket, :loading, false)
      |> stream(:vehicle_fuel_histories, results)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_vehicle_fuel_histories, {:exit, _reason}, socket) do
    {:noreply, assign(socket, :loading, :error)}
  end

  defp load_vehicle_fuel_histories(vehicle, tenant, actor) do
    Fleetms.FuelTracking.FuelHistory
    |> Ash.Query.new()
    |> Ash.Query.set_argument(:vehicle_id, vehicle.id)
    |> Ash.Query.for_read(:list_vehicle_fuel_histories)
    |> Ash.read!(tenant: tenant, actor: actor)
  end
end
