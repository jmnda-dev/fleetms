defmodule FleetmsWeb.WorkOrderLive.Detail do
  use FleetmsWeb, :live_view

  require Logger

  alias Fleetms.Accounts

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :service_module}

  @photos_upload_ref :work_order_photos
  @default_max_upload_entries 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :active_link, :work_orders)}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _, socket) do
    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    work_order =
      Fleetms.VehicleMaintenance.WorkOrder.get_by_id!(id, tenant: tenant, actor: actor)

    socket =
      socket
      |> assign(:work_order, work_order)
      |> apply_action(live_action, params)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {FleetmsWeb.WorkOrderLive.Detail, {:load_line_items, vehicle_id}},
        socket
      ) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    issues = Fleetms.VehicleIssues.Issue.get_by_vehicle_id!(vehicle_id, tenant: tenant, actor: actor)

    service_reminders =
      Fleetms.VehicleMaintenance.ServiceReminder.get_by_vehicle_id!(vehicle_id, tenant: tenant, actor: actor)

    service_tasks =
      Fleetms.VehicleMaintenance.ServiceTask.list_with_vehicle_reminder!(vehicle_id,
        tenant: tenant,
        actor: actor
      )

    socket =
      stream(socket, :vehicle_issues, issues, reset: true)
      |> stream(:vehicle_service_reminders, service_reminders, reset: true)
      |> stream(:service_tasks, service_tasks, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({FleetmsWeb.WorkOrderLive.Detail, {:issue_added, issue}}, socket) do
    socket =
      stream_delete(socket, :vehicle_issues, issue)
      |> put_toast(:info, "Issue was added to Work Order form")

    {:noreply, socket}
  end

  @impl true
  def handle_info({FleetmsWeb.WorkOrderLive.Detail, {:issue_removed, issue}}, socket) do
    socket =
      stream_insert(socket, :vehicle_issues, issue)
      |> put_toast(:info, "Issue was remove from Work Order form")

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {FleetmsWeb.WorkOrderLive.Detail, {:service_reminder_removed, service_reminder}},
        socket
      ) do
    ids =
      Enum.filter(socket.assigns.work_order_service_reminders_ids, &(&1 != service_reminder.id))

    socket =
      socket
      |> put_toast(:info, "Issue was remove from Work Order form")
      |> stream_insert(:vehicle_service_reminders, service_reminder)
      |> assign(:work_order_service_reminders_ids, ids)

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, @photos_upload_ref, ref)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    %{tenant: tenant, current_user: actor, work_order: work_order} = socket.assigns
    Ash.destroy!(work_order, tenant: tenant, actor: actor)

    socket = put_toast(socket, :info, "Work Order was deleted successfully")

    {:noreply, push_navigate(socket, to: ~p"/work_orders")}
  end

  @impl true
  def handle_event("validate", %{"work_order" => work_order_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, work_order_params)

    socket =
      assign(socket, :form, form)
      |> assign(:form_params, %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_issue", %{"issue_id" => issue_id}, socket) do
    issue = Fleetms.VehicleIssues.Issue.get_by_id!(issue_id)

    form =
      AshPhoenix.Form.add_form(socket.assigns.form, "work_order[issues]",
        type: :read,
        data: issue
      )

    notify_parent({:issue_added, issue})
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event(
        "add_service_reminder",
        %{"service_reminder_id" => service_reminder_id},
        socket
      ) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    service_reminder =
      Fleetms.VehicleMaintenance.ServiceReminder.get_for_form!(service_reminder_id,
        tenant: tenant,
        actor: actor
      )

    params = %{
      "service_task_id" => service_reminder.service_task_id,
      "service_task_name" => service_reminder.service_task.name,
      "service_reminder" => %{
        "id" => service_reminder.id,
        "mileage_interval" => service_reminder.mileage_interval,
        "time_interval" => service_reminder.time_interval,
        "time_interval_unit" => service_reminder.time_interval_unit,
        "service_group_name" => render_value(service_reminder.service_group_name),
        "is_from_service_reminder" => true
      }
    }

    form =
      AshPhoenix.Form.add_form(socket.assigns.form, "work_order[work_order_service_tasks]",
        params: params
      )

    socket =
      assign(socket, :form, form)
      |> update(:work_order_service_reminders_ids, fn ids -> [service_reminder_id | ids] end)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "add_service_task",
        %{"service_task_id" => service_task_id},
        socket
      ) do
    vehicle_id = get_form_value(socket.assigns.form, :vehicle_id)

    %{tenant: tenant, current_user: actor, form: form} = socket.assigns

    service_task =
      Fleetms.VehicleMaintenance.ServiceTask.get_for_form!(service_task_id, vehicle_id,
        tenant: tenant,
        actor: actor
      )

    service_reminder =
      cond do
        is_nil(service_task.service_reminder) or
            is_nil(Map.get(service_task.service_reminder, :id, nil)) ->
          nil

        true ->
          %{
            "id" => service_task.service_reminder.id,
            "mileage_interval" => service_task.service_reminder.mileage_interval,
            "time_interval" => service_task.service_reminder.time_interval,
            "time_interval_unit" => service_task.service_reminder.time_interval_unit,
            "service_group_name" =>
              service_task.service_reminder &&
                render_value(service_task.service_reminder, :service_group_name)
          }
      end

    params = %{
      "service_task_id" => service_task.id,
      "service_task_name" => service_task.name,
      "service_reminder" => service_reminder
    }

    form =
      AshPhoenix.Form.add_form(form, "work_order[work_order_service_tasks]", params: params)

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("remove_issue_from_form", %{"path" => path, "issue_id" => issue_id}, socket) do
    %{tenant: tenant, current_user: actor, form: form} = socket.assigns
    issue = Fleetms.VehicleIssues.Issue.get_by_id!(issue_id, tenant: tenant, actor: actor)
    form = AshPhoenix.Form.remove_form(form, path)

    notify_parent({:issue_removed, issue})
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event(
        "remove_service_reminder_from_form",
        %{"path" => path, "service_reminder_id" => service_reminder_id},
        socket
      ) do
    service_reminder = Fleetms.VehicleMaintenance.ServiceReminder.get_by_id!(service_reminder_id)
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)

    notify_parent({:service_reminder_removed, service_reminder})
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("add_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.add_form(socket.assigns.form, path)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("remove_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("vehicle_selected", %{"work_order" => work_order_params}, socket) do
    new_params =
      cond do
        socket.assigns.form.params == %{} ->
          work_order_params

        true ->
          Map.merge(socket.assigns.form.params, work_order_params)
      end

    form = AshPhoenix.Form.validate(socket.assigns.form, new_params)

    case Map.get(work_order_params, "vehicle_id") do
      nil ->
        {:noreply, assign(socket, :form, form)}

      "" ->
        {:noreply, assign(socket, :form, form)}

      vehicle_id ->
        notify_parent({:load_line_items, vehicle_id})
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("save", %{"work_order" => work_order_params}, socket) do
    save_work_order(socket, socket.assigns.live_action, work_order_params)
  end

  @impl true
  def handle_event("complete_work_order", _params, socket) do
    work_order = socket.assigns.work_order

    work_order
    |> Ash.Changeset.for_update(:complete_work_order)
    |> Ash.update!(actor: socket.assigns.current_user)

    socket =
      put_toast(socket, :info, "Work Order was marked as completed.")
      |> push_patch(to: ~p"/work_orders/#{work_order}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("reopen_work_order", _params, socket) do
    %{tenant: tenant, current_user: actor, work_order: work_order} = socket.assigns

    work_order =
      work_order
      |> Ash.load!(:issues, tenant: tenant, actor: actor)
      |> Ash.Changeset.for_update(:reopen_work_order)
      |> Ash.update!(tenant: tenant, actor: actor)

    socket = put_toast(socket, :info, "Work Order ##{work_order.work_order_number} was reopened.")

    {:noreply, push_patch(socket, to: ~p"/work_orders/#{work_order}")}
  end

  @impl true
  def handle_event(event, params, socket) do
    Logger.error(
      "Unhandled LiveView `handle_event` message. MESSAGE => `#{inspect(event)}` | PARAMS => `#{inspect(params)}"
    )

    {:noreply, socket}
  end

  defp apply_action(socket, :edit, _params) do
    work_order = socket.assigns.work_order
    work_order_issues_ids = Enum.map(work_order.issues, & &1.id)

    work_order_service_tasks_ids =
      Enum.map(work_order.work_order_service_tasks, & &1.service_task_id)

    if connected?(socket) do
      notify_parent({:load_line_items, work_order.vehicle_id})
    end

    work_order_service_reminders_ids =
      Stream.filter(work_order.work_order_service_tasks, &(not is_nil(&1.service_task.service_reminder)))
      |> Enum.map(& &1.service_task.service_reminder.id)

    max_upload_entries = get_max_upload_entries(work_order)

    socket
    |> assign_dropdown_lookup_items()
    |> assign(:page_title, "Edit Work Order")
    |> assign(:work_order, work_order)
    |> assign(:max_upload_entries, max_upload_entries)
    |> assign(:disallow_uploads, max_upload_entries == 0)
    |> assign(:upload_disallow_msg, nil)
    |> assign_upload_config()
    |> assign(:work_order_issues_ids, work_order_issues_ids)
    |> assign(:work_order_service_reminders_ids, work_order_service_reminders_ids)
    |> assign(:work_order_service_tasks_ids, work_order_service_tasks_ids)
    |> stream(:vehicle_issues, [], reset: true)
    |> stream(:vehicle_service_reminders, [], reset: true)
    |> stream(:service_tasks, [], reset: true)
    |> assign_form()
  end

  defp apply_action(socket, :detail, _params) do
    socket
    |> assign(:work_order_issues_ids, nil)
    |> assign(:work_order_service_reminders_ids, nil)
    |> assign(:form, nil)
  end

  defp save_work_order(socket, :edit, work_order_params) do
    {photos_to_delete_ids, work_order_params} =
      Map.pop(work_order_params, "photos_to_delete_ids", [])

    case AshPhoenix.Form.submit(socket.assigns.form, params: work_order_params) do
      {:ok, work_order} ->
        save_uploads(socket, work_order, photos_to_delete_ids)

        {:noreply,
         socket
         |> put_toast(:info, "Work Order updated successfully")
         |> push_patch(to: ~p"/work_orders/#{work_order}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{work_order: work_order}} = socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      work_order
      |> AshPhoenix.Form.for_update(:update,
        as: "work_order",
        domain: Fleetms.VehicleMaintenance,
        actor: actor,
        tenant: tenant,
        forms: [
          issues: [
            type: :list,
            resource: Fleetms.VehicleIssues.Issue,
            data: work_order.issues,
            update_action: :update_from_work_order,
            read_action: :read
          ],
          work_order_service_tasks: [
            type: :list,
            resource: Fleetms.VehicleMaintenance.WorkOrderServiceTask,
            data: work_order.work_order_service_tasks,
            read_action: :read_for_form,
            create_action: :create,
            update_action: :update,
            forms: [
              service_reminder: [
                type: :single,
                resource: Fleetms.VehicleMaintenance.ServiceReminder,
                data: & &1.service_task.service_reminder,
                create_action: :ignore_create,
                update_action: :ignore_update
              ],
              work_order_service_task_parts: [
                type: :list,
                resource: Fleetms.VehicleMaintenance.WorkOrderServiceTaskPart,
                data: & &1.work_order_service_task_parts,
                create_action: :create,
                update_action: :update
              ]
            ]
          ]
        ]
      )

    assign(socket, :form, form |> to_form())
  end

  def assign_dropdown_lookup_items(socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    vehicles =
      Fleetms.VehicleManagement.Vehicle.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.full_name, &1.id})

    service_tasks =
      Fleetms.VehicleMaintenance.ServiceTask.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    users =
      Accounts.get_all_users!(tenant: tenant, actor: actor)
      |> Ash.load!([user_profile: [:full_name]], tenant: tenant, actor: actor)
      |> Enum.map(&{&1.user_profile.full_name, &1.id})

    inventory_locations =
      Fleetms.Inventory.InventoryLocation.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{&1.name, &1.id})

    parts =
      Fleetms.Inventory.Part.get_all!(tenant: tenant, actor: actor)
      |> Enum.map(&{"#{&1.name} - [#{&1.part_number}]", &1.id})

    assign(socket,
      parts: parts,
      inventory_locations: inventory_locations,
      users: users,
      service_tasks: service_tasks,
      vehicles: vehicles
    )
  end

  defp has_reminder?(service_task_form) do
    case get_form_value(service_task_form, :service_reminder) do
      nil ->
        false

      # Pattern match on the id, to ensure that the map does contain data of a service reminder
      %{"id" => _id} = _service_reminder ->
        true

      # Pattern match on the id, to ensure that the map does contain data of a service reminder
      %{id: _id} = _service_reminder ->
        true

      _service_reminder ->
        false
    end
  end

  defp save_uploads(socket, work_order, photos_to_delete_ids) do
    definition_module = Fleetms.WorkOrderPhoto
    # default to empty list since vehicle.photos can be nil
    current_work_order_photos = get_current_work_order_photos(work_order)

    photos_to_keep_params =
      Stream.filter(current_work_order_photos, &(&1.id not in photos_to_delete_ids))
      |> Enum.map(&%{id: &1.id})

    %{tenant: tenant, current_user: actor} = socket.assigns

    # Check if uploads have been disallowed, so as to not run consume_uploaded_entry/3 which would fail if there is no upload config in the socket
    if socket.assigns.disallow_uploads do
      # TODO: Fix this duplication logic of updating vehcile photos, see line 207 and 216 as well
      Ash.Changeset.for_update(work_order, :maybe_delete_existing_photos, %{
        current_photos: photos_to_keep_params
      })
      |> Ash.update!(actor: actor)
    else
      case FleetmsWeb.UploadHandler.save(
             socket,
             @photos_upload_ref,
             definition_module,
             work_order
           ) do
        [] ->
          Ash.Changeset.for_update(work_order, :maybe_delete_existing_photos, %{
            current_photos: photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)

        filenames ->
          uploaded_photos_params = Enum.map(filenames, &%{filename: &1})

          Ash.Changeset.for_update(work_order, :save_work_order_photos, %{
            work_order_photos: uploaded_photos_params ++ photos_to_keep_params
          })
          |> Ash.update!(tenant: tenant, actor: actor)
      end
    end
  end

  defp get_max_upload_entries(nil), do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.VehicleMaintenance.WorkOrder{work_order_photos: nil}),
    do: @default_max_upload_entries

  defp get_max_upload_entries(%Fleetms.VehicleMaintenance.WorkOrder{work_order_photos: photos}) do
    total = Enum.count(photos)
    @default_max_upload_entries - total
  end

  defp assign_upload_config(socket) do
    max_upload_entries = socket.assigns.max_upload_entries

    upload_disallow_msg =
      "Max number of photos is reached, select photos to delete, save and upload new photos."

    if max_upload_entries == 0 do
      assign(socket, :upload_disallow_msg, upload_disallow_msg)
    else
      allow_upload(socket, @photos_upload_ref,
        accept: ~w(.jpg .jpeg .png),
        max_entries: max_upload_entries,
        max_file_size: 4096_000
      )
    end
  end

  defp get_current_work_order_photos(%Fleetms.VehicleMaintenance.WorkOrder{work_order_photos: photos})
       when is_list(photos),
       do: photos

  defp get_current_work_order_photos(%Fleetms.VehicleMaintenance.WorkOrder{work_order_photos: _photos}),
    do: []
end
