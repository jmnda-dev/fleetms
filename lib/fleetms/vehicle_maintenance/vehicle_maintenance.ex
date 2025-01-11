defmodule Fleetms.VehicleMaintenance do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  authorization do
    authorize :always
  end

  resources do
    resource Fleetms.VehicleMaintenance.ServiceGroup

    resource Fleetms.VehicleMaintenance.ServiceReminder do
      define :list_service_reminders,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]
    end

    resource Fleetms.VehicleMaintenance.ServiceTask

    resource Fleetms.VehicleMaintenance.WorkOrder do
      define :list_work_orders,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]

      define :get_work_order_by_id, action: :get_by_id, args: [:id]
    end

    resource Fleetms.VehicleMaintenance.WorkOrderPhoto
    resource Fleetms.VehicleMaintenance.ServiceGroupVehicle
    resource Fleetms.VehicleMaintenance.WorkOrderServiceTask
    resource Fleetms.VehicleMaintenance.WorkOrderServiceTaskPart
    resource Fleetms.VehicleMaintenance.WorkOrderServiceTaskTechnicianLaborDetail
    resource Fleetms.VehicleMaintenance.WorkOrderServiceTaskVendorLaborDetail
    resource Fleetms.VehicleMaintenance.ServiceReminderHistory
    resource Fleetms.VehicleMaintenance.ServiceGroupSchedule
    resource Fleetms.VehicleMaintenance.ServiceGroupScheduleServiceTask
  end

  admin do
    show? true
  end
end
