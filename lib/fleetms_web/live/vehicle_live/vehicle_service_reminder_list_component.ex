defmodule FleetmsWeb.VehicleLive.VehicleServiceReminderListComponent do
  use FleetmsWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mx-4 pb-3 flex flex-wrap">
        <div class="hidden md:flex items-center text-sm font-medium text-gray-900 dark:text-white mr-4 mt-3">
          Show only:
        </div>
        <div class="flex flex-wrap">
          <div class="flex items-center mt-3 mr-4">
            <input
              id="inline-radio"
              type="radio"
              value=""
              name="inline-radio-group"
              class="w-4 h-4 text-primary-600 bg-gray-100 border-gray-300 focus:ring-primary-500 dark:focus:ring-primary-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
            />
            <label
              for="inline-radio"
              class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300"
            >
              All
            </label>
          </div>
          <div class="flex items-center mr-4 mt-3">
            <input
              id="inline-2-radio"
              type="radio"
              value=""
              name="inline-radio-group"
              class="w-4 h-4 text-primary-600 bg-gray-100 border-gray-300 focus:ring-primary-500 dark:focus:ring-primary-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
            />
            <label
              for="inline-2-radio"
              class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300"
            >
              Upcoming
            </label>
          </div>
          <div class="flex items-center mr-4 mt-3">
            <input
              id="inline-4-radio"
              type="radio"
              value=""
              name="inline-radio-group"
              class="w-4 h-4 text-primary-600 bg-gray-100 border-gray-300 focus:ring-primary-500 dark:focus:ring-primary-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
            />
            <label
              for="inline-4-radio"
              class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300"
            >
              Due Soon
            </label>
          </div>
          <div class="flex items-center mr-4 mt-3">
            <input
              id="inline-4-radio"
              type="radio"
              value=""
              name="inline-radio-group"
              class="w-4 h-4 text-primary-600 bg-gray-100 border-gray-300 focus:ring-primary-500 dark:focus:ring-primary-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
            />
            <label
              for="inline-4-radio"
              class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300"
            >
              Overdue
            </label>
          </div>
        </div>
      </div>

      <div :if={@loading} class="flex justify-center">
        <.spinner class="text-center" />
      </div>

      <.table_2
        :if={not @loading}
        id="service_reminders"
        rows={@streams.vehicle_service_reminders}
        row_click={
          fn {_id, service_reminder} ->
            JS.navigate(~p"/service_reminders/#{service_reminder}")
          end
        }
      >
        <:col :let={{_id, _service_reminder}} label="Name">
          <%= @vehicle.full_name %>
        </:col>

        <:col :let={{_id, service_reminder}} label="Service Group">
          <%= service_reminder.service_group_name %>
        </:col>

        <:col :let={{_id, service_reminder}} label="Service Task">
          <%= service_reminder.service_task.name %>
        </:col>

        <:col :let={{_id, service_reminder}} label="Interval">
          <%= cond do %>
            <% service_reminder.mileage_interval && service_reminder.time_interval -> %>
              Every <%= service_reminder.mileage_interval %>km or <%= service_reminder.time_interval %> <%= service_reminder.time_interval_unit %>
            <% service_reminder.mileage_interval -> %>
              Every <%= service_reminder.mileage_interval %>km
            <% service_reminder.time_interval -> %>
              Every <%= service_reminder.time_interval %> <%= service_reminder.time_interval_unit %>
            <% true -> %>
              --
          <% end %>
        </:col>

        <:col :let={{_id, service_reminder}} label="Due Status">
          <.badge
            :if={service_reminder.due_status == :Upcoming}
            kind={:info}
            label={service_reminder.due_status}
          />
          <.badge
            :if={service_reminder.due_status == :"Due Soon"}
            kind={:warning}
            label={service_reminder.due_status}
          />
          <.badge
            :if={service_reminder.due_status == :Overdue}
            kind={:danger}
            label={service_reminder.due_status}
          />
        </:col>
        <:col :let={{_id, service_reminder}} label="Next Due">
          <%= cond do %>
            <% service_reminder.mileage_interval && service_reminder.time_interval -> %>
              <.badge label={"#{service_reminder.next_due_mileage}km"} /> or
              <.badge label={service_reminder.next_due_date} />
            <% service_reminder.mileage_interval -> %>
              <.badge label={"#{service_reminder.next_due_mileage}km"} />
            <% service_reminder.time_interval -> %>
              <.badge label={service_reminder.next_due_date} />
            <% true -> %>
              --
          <% end %>
        </:col>
      </.table_2>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream(:vehicle_service_reminders, [])
     |> assign(:loading, true)}
  end

  @impl true
  def update(%{vehicle: vehicle} = assigns, socket) do
    socket =
      assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    socket =
      socket
      |> start_async(:get_service_reminders, fn ->
        load_issues(vehicle, tenant, actor)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_async(
        :get_service_reminders,
        {:ok, %Ash.Page.Offset{results: results} = _result},
        socket
      ) do
    socket =
      assign(socket, :loading, false)
      |> stream(:vehicle_service_reminders, results)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_service_reminders, {:exit, _reason}, socket) do
    {:noreply, assign(socket, :loading, :error)}
  end

  defp load_issues(vehicle, tenant, actor) do
    Fleetms.Service.ServiceReminder
    |> Ash.Query.new()
    |> Ash.Query.set_argument(:vehicle_id, vehicle.id)
    |> Ash.Query.for_read(:list_vehicle_service_reminders)
    |> Ash.read!(tenant: tenant, actor: actor)
  end
end
