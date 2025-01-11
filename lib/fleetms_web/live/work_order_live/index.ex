defmodule FleetmsWeb.WorkOrderLive.Index do
  use FleetmsWeb, :live_view
  require Logger

  alias Fleetms.Accounts

  import Fleetms.Utils,
    only: [calc_total_pages: 2, dates_in_map_to_string: 2, atom_list_to_options_for_select: 1]

  alias Fleetms.Common.PaginationSortParam
  alias Fleetms.VehicleMaintenance

  alias FleetmsWeb.LiveUserAuth

  on_mount {LiveUserAuth, :service_module}

  @photos_upload_ref :work_order_photos
  @default_max_upload_entries 10
  @per_page_opts [10, 20, 30, 50, 100, 250, 500]
  @sort_by_opts [
    :created_at,
    :updated_at,
    :date_and_time_issued,
    :date_and_time_started,
    :date_and_time_completed,
    :status,
    :count_of_service_tasks,
    :repair_category
  ]
  @default_listing_limit 20
  @sort_order [:asc, :desc]
  @default_paginate_sort_params %{
    page: 1,
    per_page: @default_listing_limit,
    sort_by: :updated_at,
    sort_order: :desc
  }
  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_link, :work_orders)
      |> stream(:work_orders, [])
      |> assign(:total, 0)
      |> assign(:total_pages, 0)
      |> assign(:search_params, %{search_query: ""})
      |> assign(:has_more?, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    paginate_sort_opts = validate_paginate_sort_params(params)

    search_query = Map.get(params, "search_query", "")

    filter_form_data = filter_form_data_from_url_params(params)

    filter_form_data_with_string_dates =
      filter_form_data
      |> dates_in_map_to_string([
        :date_and_time_issued_from,
        :date_and_time_issued_to,
        :date_and_time_started_from,
        :date_and_time_started_to,
        :date_and_time_completed_from,
        :date_and_time_completed_to
      ])

    %{tenant: tenant, current_user: actor, live_action: live_action} = socket.assigns

    socket =
      socket
      |> assign(:paginate_sort_opts, paginate_sort_opts)
      |> assign(:loading, true)
      |> assign(:search_params, %{search_query: search_query})
      |> assign(:filter_form_data, filter_form_data_with_string_dates)
      |> start_async(:get_work_orders, fn ->
        list_work_orders(
          paginate_sort_opts,
          search_query,
          filter_form_data,
          tenant: tenant,
          actor: actor
        )
      end)

    {:noreply, apply_action(socket, live_action, params)}
  end

  @impl true
  def handle_async(:get_work_orders, {:ok, result}, socket) do
    %Ash.Page.Offset{
      count: count,
      results: results,
      more?: has_more?
    } = result

    %{per_page: per_page} = socket.assigns.paginate_sort_opts

    socket =
      assign(socket, :loading, false)
      |> stream(:work_orders, results, reset: true)
      |> assign(has_more?: has_more?)
      |> assign(:total, count)
      |> assign(:total_pages, calc_total_pages(count, per_page))

    {:noreply, socket}
  end

  @impl true
  def handle_async(:get_work_orders, {:error, _reason}, socket) do
    {:noreply, assign(socket, :loading, :error)}
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, @photos_upload_ref, ref)}
  end

  @impl true
  def handle_event(
        "items_per_page_changed",
        %{"paginate_sort_opts" => %{"per_page" => per_page}},
        socket
      ) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:per_page, per_page)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/work_orders?#{new_url_params}")}
  end

  @impl true
  def handle_event(
        "sort_order_changed",
        %{"paginate_sort_opts" => %{"sort_order" => sort_order}},
        socket
      ) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_order, sort_order)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/work_orders?#{new_url_params}")}
  end

  @impl true
  def handle_event("sort_by_changed", %{"paginate_sort_opts" => %{"sort_by" => sort_by}}, socket) do
    new_url_params =
      socket.assigns.paginate_sort_opts
      |> Map.put(:sort_by, sort_by)
      |> Map.merge(socket.assigns.search_params)
      |> Map.merge(socket.assigns.filter_form_data)

    {:noreply, push_patch(socket, to: ~p"/work_orders?#{new_url_params}")}
  end

  @impl true
  def handle_event("search", %{"work_order_search" => work_order_search}, socket) do
    search_params = %{search_query: work_order_search["search_query"]}

    new_url_params =
      Map.merge(search_params, socket.assigns.paginate_sort_opts)
      |> Map.merge(socket.assigns.filter_form_data)

    socket = assign(socket, :search_params, search_params)

    {:noreply, push_patch(socket, to: ~p"/work_orders?#{new_url_params}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    work_order = Fleetms.VehicleMaintenance.WorkOrder.get_by_id!(id, tenant: tenant, actor: actor)

    Ash.destroy!(work_order, tenant: tenant, actor: actor)

    socket =
      socket
      |> stream_delete(:work_orders, work_order)
      |> put_toast(:info, "Work Order was deleted successfully")

    {:noreply, socket}
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
    %{tenant: tenant, current_user: actor, form: form} = socket.assigns
    issue = Fleetms.VehicleIssues.Issue.get_by_id!(issue_id, tenant: tenant, actor: actor)

    form =
      AshPhoenix.Form.add_form(form, "work_order[issues]",
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
    %{tenant: tenant, current_user: actor} = socket.assigns
    vehicle_id = get_form_value(socket.assigns.form, :vehicle_id)

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
      AshPhoenix.Form.add_form(socket.assigns.form, "work_order[work_order_service_tasks]",
        params: params
      )

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
    %{tenant: tenant, current_user: actor, form: form} = socket.assigns

    service_reminder =
      Fleetms.VehicleMaintenance.ServiceReminder.get_by_id!(service_reminder_id,
        tenant: tenant,
        actor: actor
      )

    form = AshPhoenix.Form.remove_form(form, path)

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
  def handle_event(event, params, socket) do
    Logger.error(
      "Unhandled LiveView `handle_event` message. MESSAGE => `#{inspect(event)}` | PARAMS => `#{inspect(params)}"
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({FleetmsWeb.WorkOrderLive.Index, {:saved, work_order}}, socket) do
    {:noreply, stream_insert(socket, :work_orders, work_order)}
  end

  @impl true
  def handle_info(
        {FleetmsWeb.WorkOrderLive.Index, {:load_line_items, vehicle_id}},
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
  def handle_info({FleetmsWeb.WorkOrderLive.Index, {:issue_added, issue}}, socket) do
    socket =
      stream_delete(socket, :vehicle_issues, issue)
      |> put_toast(:info, "Issue was added to Work Order form")

    {:noreply, socket}
  end

  @impl true
  def handle_info({FleetmsWeb.WorkOrderLive.Index, {:issue_removed, issue}}, socket) do
    socket =
      stream_insert(socket, :vehicle_issues, issue)
      |> put_toast(:info, "Issue was remove from Work Order form")

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {FleetmsWeb.WorkOrderLive.Index, {:service_reminder_removed, service_reminder}},
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

  defp apply_action(socket, :edit, %{"id" => id}) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    work_order = Fleetms.VehicleMaintenance.WorkOrder.get_by_id!(id, tenant: tenant, actor: actor)

    can_perform_action? =
      Ash.can?(
        {work_order, :update},
        actor
      )

    if can_perform_action? do
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
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :new, _params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.VehicleMaintenance.WorkOrder, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      max_upload_entries = get_max_upload_entries(nil)

      socket
      |> assign(:page_title, "New Work Order")
      |> assign(:work_order, nil)
      |> assign_dropdown_lookup_items()
      |> assign(:max_upload_entries, max_upload_entries)
      |> assign(:disallow_uploads, max_upload_entries == 0)
      |> assign(:upload_disallow_msg, nil)
      |> assign_upload_config()
      |> assign(:work_order_issues_ids, [])
      |> assign(:work_order_service_reminders_ids, [])
      |> stream(:vehicle_issues, [], reset: true)
      |> stream(:vehicle_service_reminders, [], reset: true)
      |> stream(:service_tasks, [], reset: true)
      |> assign_form()
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Work Orders")
    |> assign(:work_order, nil)
    |> assign(:work_order_issues_ids, nil)
    |> assign(:work_order_service_reminders_ids, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, :filter_form, _params) do
    socket
    |> assign(:page_title, "Filtering Work Orders")
  end

  defp save_work_order(socket, :edit, work_order_params) do
    %{current_user: actor, work_order: work_order} = socket.assigns

    can_perform_action? =
      Ash.can?(
        {work_order, :update},
        actor
      )

    if can_perform_action? do
      {photos_to_delete_ids, work_order_params} =
        Map.pop(work_order_params, "photos_to_delete_ids", [])

      case AshPhoenix.Form.submit(socket.assigns.form, params: work_order_params) do
        {:ok, work_order} ->
          notify_parent({:saved, work_order})
          save_uploads(socket, work_order, photos_to_delete_ids)

          {:noreply,
           socket
           |> put_toast(:info, "Work Order updated successfully")
           |> push_patch(to: ~p"/work_orders")}

        {:error, form} ->
          {:noreply, assign(socket, :form, form)}
      end
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp save_work_order(socket, :new, work_order_params) do
    can_perform_action? =
      Ash.can?(
        {Fleetms.VehicleMaintenance.WorkOrder, :create},
        socket.assigns.current_user
      )

    if can_perform_action? do
      case AshPhoenix.Form.submit(socket.assigns.form, params: work_order_params) do
        {:ok, work_order} ->
          notify_parent({:saved, work_order})
          save_uploads(socket, work_order)

          {:noreply,
           socket
           |> put_toast(:info, "Work Order created successfully")
           |> push_patch(to: ~p"/work_orders")}

        {:error, form} ->
          {:noreply, assign(socket, :form, form)}
      end
    else
      raise FleetmsWeb.Exceptions.UnauthorizedError,
            "You are not authorized to perform this action"

      {:noreply, socket}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{work_order: work_order}} = socket) do
    %{tenant: tenant, current_user: actor} = socket.assigns

    form =
      if work_order do
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
              ],
            ]
          ]
          ]
        )
      else
        Fleetms.VehicleMaintenance.WorkOrder
        |> AshPhoenix.Form.for_create(:create,
          as: "work_order",
          domain: Fleetms.VehicleMaintenance,
          actor: actor,
          tenant: tenant,
          forms: [
            issues: [
              type: :list,
              resource: Fleetms.VehicleIssues.Issue,
              update_action: :update_from_work_order,
              read_action: :read
            ],
            work_order_service_tasks: [
              type: :list,
              resource: Fleetms.VehicleMaintenance.WorkOrderServiceTask,
              create_action: :create,
              update_action: :update,
              forms: [
                service_reminder: [
                  type: :single,
                  resource: Fleetms.VehicleMaintenance.ServiceReminder,
                  create_action: :ignore_create,
                  update_action: :ignore_update
                ],
                work_order_service_task_parts: [
                  type: :list,
                  resource: Fleetms.VehicleMaintenance.WorkOrderServiceTaskPart,
                  create_action: :create
                ],
                work_order_service_task_vendor_labor_details: [
                  type: :list,
                  resource: Fleetms.VehicleMaintenance.WorkOrderServiceTaskVendorLaborDetail,
                  create_action: :create
                ],
                work_order_service_task_technician_labor_details: [
                  type: :list,
                  resource: Fleetms.VehicleMaintenance.WorkOrderServiceTaskTechnicianLaborDetail,
                  create_action: :create
                ]
              ]
            ]
          ]
        )
      end

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
      |> Ash.load!(user_profile: [:full_name])
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

  defp save_uploads(socket, work_order, photos_to_delete_ids \\ [])

  defp save_uploads(socket, work_order, photos_to_delete_ids) do
    %{tenant: tenant, current_user: actor} = socket.assigns
    definition_module = Fleetms.WorkOrderPhoto
    # default to empty list since vehicle.photos can be nil
    current_work_order_photos = get_current_work_order_photos(work_order)

    photos_to_keep_params =
      Stream.filter(current_work_order_photos, &(&1.id not in photos_to_delete_ids))
      |> Enum.map(&%{id: &1.id})

    # Check if uploads have been disallowed, so as to not run consume_uploaded_entry/3 which would fail if there is no upload config in the socket
    if socket.assigns.disallow_uploads do
      # TODO: Fix this duplication logic of updating vehcile photos, see line 207 and 216 as well
      Ash.Changeset.for_update(work_order, :maybe_delete_existing_photos, %{
        current_photos: photos_to_keep_params
      })
      |> Ash.update!(tenant: tenant, actor: actor)
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

  defp list_work_orders(paginate_sort_opts, search_query, filter_form_data, opts) do
    %{page: page, per_page: per_page} = paginate_sort_opts

    VehicleMaintenance.list_work_orders!(paginate_sort_opts, search_query, filter_form_data,
      tenant: opts[:tenant],
      actor: opts[:actor],
      page: [limit: per_page, offset: (page - 1) * per_page, count: true]
    )
  end

  defp validate_paginate_sort_params(params) do
    paginate_sort_params = Map.take(params, ["page", "per_page", "sort_by", "sort_order"])

    case PaginationSortParam.validate(@per_page_opts, @sort_by_opts, paginate_sort_params) do
      {:ok, validated_params} ->
        Map.take(validated_params, [:page, :per_page, :sort_by, :sort_order])

      {:error, _error} ->
        @default_paginate_sort_params
    end
  end

  defp filter_form_data_from_url_params(url_params) do
    params =
      Map.take(url_params, [
        "vehicles",
        "statuses",
        "repair_categories",
        "assigned_to",
        "issued_by",
        "date_and_time_issued_from",
        "date_and_time_issued_to",
        "date_and_time_started_from",
        "date_and_time_started_to",
        "date_and_time_completed_from",
        "date_and_time_completed_to"
      ])

    FleetmsWeb.WorkOrderLive.FilterFormComponent.build_filter_changeset(%{}, params)
    |> Ecto.Changeset.apply_action(:create)
    |> case do
      {:ok, validated_filter_params} ->
        validated_filter_params

      {:error, _changeset} ->
        %{}
    end
  end

  defp get_items_per_page_opts, do: @per_page_opts
  defp get_sort_by_opts, do: atom_list_to_options_for_select(@sort_by_opts)
  defp get_sort_order_opts, do: atom_list_to_options_for_select(@sort_order)

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
