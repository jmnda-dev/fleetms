defmodule FleetmsWeb.ServiceReminderLive.FormComponent do
  use FleetmsWeb, :live_component
  require Logger

  @impl true
  def update(%{service_reminder: service_reminder} = assigns, socket) do
    socket = assign(socket, assigns)
    {form, is_not_editable?} = get_form(socket, service_reminder)

    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicles =
      Fleetms.Vehicles.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    service_tasks =
      Fleetms.Service.ServiceTask.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    {:ok,
     socket
     |> assign(:form, form |> to_form())
     |> assign(:items, [%{value: "one", label: "One"}, %{value: "two", label: "Two"}])
     |> assign(:is_not_editable?, is_not_editable?)
     |> assign(:vehicles, vehicles)
     |> assign(:service_tasks, service_tasks)
     |> assign(:service_reminder, service_reminder)
     |> assign(:form_alert, %{show: nil, kind: :info, message: nil})}
  end

  @impl true
  def handle_event(
        "validate",
        %{"service_reminder" => service_reminder_params},
        %{assigns: %{form_alert: form_alert}} = socket
      ) do
    form = AshPhoenix.Form.validate(socket.assigns.form, service_reminder_params)

    socket =
      if form_alert.show do
        assign(socket, :form_alert, %{form_alert | show: nil})
      else
        socket
      end

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"service_reminder" => service_reminder_params}, socket) do
    save_service_reminder(socket, socket.assigns.action, service_reminder_params)
  end

  @impl true
  def handle_event(event, params, socket) do
    # TODO: This is used to handle a case where the service reminder does not belong to a service group
    # hence some fields are disable and cannot be edited. Due to this, we cannot pattern match on the params like
    # this `%{"service_reminder"=> service_reminder_params}`. This is fine because since the fields are disabled,
    # the form params are not sent.
    Logger.warning(
      "Unhandled Event in module: `#{__MODULE__}`. EVENT: `#{inspect(event)}`, PARAMS: `#{inspect(params)}"
    )

    {:noreply, socket}
  end

  defp save_service_reminder(socket, :edit, service_reminder_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: service_reminder_params) do
      {:ok, service_reminder} ->
        notify_parent({:saved, service_reminder})

        {:noreply,
         socket
         |> put_flash(:info, "Service Reminder updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        socket = maybe_assign_form_error(form, socket)
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp save_service_reminder(socket, :new, service_reminder_params) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: service_reminder_params) do
      {:ok, service_reminder} ->
        notify_parent({:saved, service_reminder})

        {:noreply,
         socket
         |> put_flash(:info, "Service Reminder created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, form} ->
        socket = maybe_assign_form_error(form, socket)
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp maybe_assign_form_error(form, socket) do
    error =
      AshPhoenix.Form.errors(form, format: :simple)
      |> Keyword.get(:vehicle_id)

    # TODO: Revise this and find a better way to check if a reminder with the specified service task and vehicle already exists
    if error == "has already been taken" do
      assign(socket, :form_alert, %{
        show: true,
        kind: :error,
        message: "A Service Reminder with the provided Service Task and Vehicle already exists."
      })
    else
      socket
    end
  end

  defp get_form(socket, service_reminder) when is_nil(service_reminder) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      Fleetms.Service.ServiceReminder
      |> AshPhoenix.Form.for_create(:create,
        as: "service_reminder",
        domain: Fleetms.Service,
        actor: actor,
        tenant: tenant,
        forms: [auto?: true]
      )

    is_not_editable? = false
    {form, is_not_editable?}
  end

  defp get_form(socket, service_reminder) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    case service_reminder.service_group_schedule_id do
      nil ->
        form =
          service_reminder
          |> AshPhoenix.Form.for_update(:update,
            as: "service_reminder",
            domain: Fleetms.Service,
            actor: actor,
            tenant: tenant,
            forms: [auto?: true]
          )

        is_not_editable? = false
        {form, is_not_editable?}

      _service_group_schedule_id ->
        form =
          service_reminder
          |> AshPhoenix.Form.for_update(:reminder_with_service_group_schedule,
            as: "service_reminder",
            domain: Fleetms.Service,
            actor: actor,
            tenant: tenant,
            forms: [auto?: true]
          )

        is_not_editable? = true
        {form, is_not_editable?}
    end
  end
end
