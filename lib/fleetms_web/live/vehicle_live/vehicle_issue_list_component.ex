defmodule FleetmsWeb.VehicleLive.VehicleIssueListComponent do
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
              Open
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
              Resolved
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
              Closed
            </label>
          </div>
        </div>
      </div>

      <div :if={@loading} class="flex justify-center">
        <.spinner class="text-center" />
      </div>

      <.table_2
        :if={not @loading}
        id="issues"
        rows={@streams.vehicle_issues}
        row_click={fn {_id, issue} -> JS.navigate(~p"/issues/#{issue}") end}
      >
        <:col :let={{_id, _issue}} label="Vehicle">
          <%= @vehicle.full_name %>
        </:col>
        <:col :let={{_id, issue}} label="Title"><%= issue.title %></:col>
        <:col :let={{_id, issue}} label="Status">
          <.badge :if={issue.status == :Open} kind={:primary} label={issue.status} />
          <.badge :if={issue.status == :Closed} kind={:warning} label={issue.status} />
          <.badge :if={issue.status == :Resolved} kind={:success} label={issue.status} />
        </:col>

        <:col :let={{_id, issue}} label="Date Reported"><%= issue.date_reported %></:col>
      </.table_2>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream(:vehicle_issues, [])
     |> assign(:loading, true)}
  end

  @impl true
  def update(%{vehicle: vehicle} = assigns, socket) do
    socket =
      assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    socket =
      socket
      |> start_async(:get_issues, fn ->
        load_issues(vehicle, tenant, actor)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_async(:get_issues, {:ok, %Ash.Page.Offset{results: results} = _result}, socket) do
    socket =
      assign(socket, :loading, false)
      |> stream(:vehicle_issues, results)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_issues, {:exit, _reason}, socket) do
    {:noreply, assign(socket, :loading, :error)}
  end

  defp load_issues(vehicle, tenant, actor) do
    Fleetms.VehicleIssues.Issue
    |> Ash.Query.new()
    |> Ash.Query.set_argument(:vehicle_id, vehicle.id)
    |> Ash.Query.for_read(:list_vehicle_issues)
    |> Ash.read!(tenant: tenant, actor: actor)
  end
end
