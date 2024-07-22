defmodule Fleetms.Service do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  authorization do
    authorize :always
  end

  resources do
    resource Fleetms.Service.ServiceGroup
    resource Fleetms.Service.ServiceReminder
    resource Fleetms.Service.ServiceTask
    resource Fleetms.Service.WorkOrder
    resource Fleetms.Service.WorkOrderPhoto
    resource Fleetms.Service.ServiceGroupVehicle
    resource Fleetms.Service.WorkOrderServiceTask
    resource Fleetms.Service.WorkOrderServiceTaskPart
    resource Fleetms.Service.WorkOrderServiceTaskTechnicianLaborDetail
    resource Fleetms.Service.WorkOrderServiceTaskVendorLaborDetail
    resource Fleetms.Service.ServiceReminderHistory
    resource Fleetms.Service.ServiceGroupSchedule
    resource Fleetms.Service.ServiceGroupScheduleServiceTask
  end

  admin do
    show? true
  end
end
