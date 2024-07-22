defmodule FleetmsWeb.ServiceGroupLive.ScheduleFormComponent do
  use FleetmsWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>

      <.simple_form
        for={@form}
        id="service_group_schedule-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid gap-4 mb-4 sm:grid-cols-2">
          <.input field={@form[:time_interval]} type="number" label="Time Interval" />
          <.input
            field={@form[:time_interval_unit]}
            type="select"
            prompt=""
            options={Fleetms.Enums.time_units()}
            label="Time Interval Unit"
          />
          <.input field={@form[:mileage_interval]} type="number" label="Mileage Interval(km)" />
          <.input field={@form[:mileage_threshold]} type="number" label="Mileage Threshold(km)" />
          <.input field={@form[:time_threshold]} type="number" label="Time Threshold" />
          <.input
            field={@form[:time_threshold_unit]}
            type="select"
            prompt=""
            options={Fleetms.Enums.time_units()}
            label="Time Threshold Unit"
          />
        </div>
        <div id="service_tasks-input" phx-update="ignore">
          <.input
            field={@form[:service_tasks]}
            type="select"
            options={@service_tasks}
            value={
              @service_group_schedule && Enum.map(@service_group_schedule.service_tasks, & &1.id)
            }
            multiple
            phx-hook="select2JS"
            style="width: 100%;"
            label="Service Tasks"
          />
        </div>

        <:actions>
          <.button phx-disable-with="Saving...">
            <i class="fa-solid fa-floppy-disk me-1"></i>Save Schedule
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{service_group_schedule: service_group_schedule} = assigns, socket) do
    socket =
      assign(socket, assigns)

    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      if service_group_schedule do
        service_group_schedule
        |> AshPhoenix.Form.for_action(:update,
          as: "service_group_schedule",
          domain: Fleetms.Service,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      else
        Fleetms.Service.ServiceGroupSchedule
        |> AshPhoenix.Form.for_create(:create,
          as: "service_group_schedule",
          domain: Fleetms.Service,
          actor: actor,
          tenant: tenant,
          forms: [auto?: true]
        )
      end

    service_tasks =
      Fleetms.Service.ServiceTask.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    {:ok,
     socket
     |> assign(:form, form |> to_form())
     |> assign(:service_tasks, service_tasks)
     |> assign(:service_group_schedule, service_group_schedule)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"service_group_schedule" => service_group_schedule_params},
        socket
      ) do
    form = AshPhoenix.Form.validate(socket.assigns.form, service_group_schedule_params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"service_group_schedule" => service_group_schedule_params}, socket) do
    save_service_group_schedule(socket, socket.assigns.action, service_group_schedule_params)
  end

  defp save_service_group_schedule(
         socket,
         :edit_service_group_schedule,
         service_group_schedule_params
       ) do
    updated_params =
      Map.put(service_group_schedule_params, "service_group_id", socket.assigns.service_group.id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: updated_params) do
      {:ok, service_group_schedule} ->
        notify_parent({:saved, service_group_schedule})

        {:noreply,
         socket
         |> put_flash(:info, "Service Group Schedule updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        # TODO: Show unique constraint errors, where a reminder for a vehicle exists and the
        # same vehicle is added to the service group
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_service_group_schedule(
         socket,
         :add_service_group_schedule,
         service_group_schedule_params
       ) do
    service_group = socket.assigns.service_group
    vehicle_ids = Map.get(service_group, :vehicles) |> Enum.map(& &1.id)

    updated_params =
      service_group_schedule_params
      |> Map.put("service_group_id", service_group.id)
      |> Map.put("vehicles", vehicle_ids)

    case AshPhoenix.Form.submit(socket.assigns.form, params: updated_params) do
      {:ok, service_group_schedule} ->
        notify_parent({:saved, service_group_schedule})

        {:noreply,
         socket
         |> put_flash(:info, "Service Group Schedule created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
