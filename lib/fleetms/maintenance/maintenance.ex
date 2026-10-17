defmodule Fleetms.Maintenance do
  @moduledoc """
  The maintenance domain: the work a fleet does to keep its vehicles running.

  The **service task** catalogue defines the reusable pieces of maintenance work
  (e.g. "Oil & filter change", "Tyre rotation"). A **work order** records work
  carried out on a vehicle as a set of those service tasks, each with the parts it
  used, and moves through an `open → in_progress → completed` lifecycle. The join
  resources (`WorkOrderServiceTask`, `WorkOrderServiceTaskPart`) are managed through
  the work order and have no standalone code interface.
  """
  use Ash.Domain, otp_app: :fleetms, extensions: [AshPhoenix, AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/work-orders", Fleetms.Maintenance.WorkOrder do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:start, route: "/:id/start")
        patch(:complete, route: "/:id/complete")
        patch(:reopen, route: "/:id/reopen")
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end

      base_route "/service-reminders", Fleetms.Maintenance.ServiceReminder do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:reset, route: "/:id/reset")
        patch(:snooze, route: "/:id/snooze")
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end

      base_route "/vendors", Fleetms.Maintenance.Vendor do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        patch(:restore, route: "/:id/restore")
        delete(:destroy)
      end

      base_route "/service-tasks", Fleetms.Maintenance.ServiceTask do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        delete(:destroy)
      end

      base_route "/service-groups", Fleetms.Maintenance.ServiceGroup do
        index :list
        get(:get_by_id)
        post(:create)
        patch(:update)
        delete(:destroy)
      end
    end
  end

  resources do
    resource Fleetms.Maintenance.ServiceTask do
      define :list_service_tasks, action: :list
      define :get_service_task, action: :get_by_id, args: [:id]
      define :create_service_task, action: :create
      define :update_service_task, action: :update
      define :delete_service_task, action: :destroy
    end

    resource Fleetms.Maintenance.WorkOrder do
      define :list_work_orders, action: :list
      define :list_archived_work_orders, action: :list_archived
      define :list_vehicle_work_orders, action: :list_by_vehicle, args: [:vehicle_id]
      define :get_work_order, action: :get_by_id, args: [:id]
      define :create_work_order, action: :create
      define :update_work_order, action: :update
      define :start_work_order, action: :start
      define :complete_work_order, action: :complete
      define :reopen_work_order, action: :reopen
      define :delete_work_order, action: :destroy
      define :purge_work_order, action: :purge
      define :restore_work_order, action: :restore
    end

    # Audit-trail version rows (AshPaperTrail), read for the History timeline.
    resource Fleetms.Maintenance.WorkOrder.Version

    resource Fleetms.Maintenance.WorkOrderServiceTask
    resource Fleetms.Maintenance.WorkOrderServiceTaskPart
    resource Fleetms.Maintenance.WorkOrderServiceTaskLaborItem

    resource Fleetms.Maintenance.WorkOrderPhoto do
      define :upload_work_order_photo, action: :upload
      define :delete_work_order_photo, action: :destroy
    end

    resource Fleetms.Maintenance.WorkOrderDocument do
      define :upload_work_order_document, action: :upload
      define :delete_work_order_document, action: :destroy
    end

    resource Fleetms.Maintenance.ServiceReminder do
      define :list_service_reminders, action: :list
      define :list_archived_service_reminders, action: :list_archived
      define :list_vehicle_service_reminders, action: :list_by_vehicle, args: [:vehicle_id]
      define :get_service_reminder, action: :get_by_id, args: [:id]
      define :create_service_reminder, action: :create
      define :update_service_reminder, action: :update
      define :reset_service_reminder, action: :reset
      define :snooze_service_reminder, action: :snooze, args: [:days]
      define :delete_service_reminder, action: :destroy
      define :restore_service_reminder, action: :restore
    end

    resource Fleetms.Maintenance.ServiceGroup do
      define :list_service_groups, action: :list
      define :get_service_group, action: :get_by_id, args: [:id]
      define :create_service_group, action: :create
      define :update_service_group, action: :update
      define :delete_service_group, action: :destroy
    end

    resource Fleetms.Maintenance.ServiceGroupSchedule
    resource Fleetms.Maintenance.ServiceGroupVehicle

    resource Fleetms.Maintenance.Vendor do
      define :list_vendors, action: :list
      define :list_archived_vendors, action: :list_archived
      define :get_vendor, action: :get_by_id, args: [:id]
      define :create_vendor, action: :create
      define :update_vendor, action: :update
      define :delete_vendor, action: :destroy
      define :restore_vendor, action: :restore
    end
  end
end
