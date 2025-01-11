defmodule Fleetms.VehicleManagement do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.VehicleManagement.VehicleListFilter

    resource Fleetms.VehicleManagement.Vehicle do
      define :list_vehicles,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :filters]
    end

    resource Fleetms.VehicleManagement.VehicleMake
    resource Fleetms.VehicleManagement.VehicleModel
    resource Fleetms.VehicleManagement.VehiclePhoto

    resource Fleetms.VehicleManagement.VehicleDocument do
      define :list_documents_by_vehicle, action: :list_by_vehicle, args: [:vehicle_id]
      define :get_document_by_id, action: :get_by_id, args: [:id]
    end

    resource Fleetms.VehicleManagement.VehicleGroup
    resource Fleetms.VehicleManagement.VehicleEngineSpec
    resource Fleetms.VehicleManagement.VehicleDrivetrainSpec

    resource Fleetms.VehicleManagement.VehicleAssignment do
      define :list_vehicle_assignments,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]
    end

    resource Fleetms.VehicleManagement.VehicleOtherSpec
    resource Fleetms.VehicleManagement.VehiclePerformanceSpec
    resource Fleetms.VehicleManagement.VehicleReminderPurpose

    resource Fleetms.VehicleManagement.VehicleGeneralReminder do
      define :list_vehicle_general_reminders,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]

      define :get_due_vehicle_general_reminders, action: :get_due
    end

    resource Fleetms.VehicleMaintenance.ServiceGroupVehicle
    resource Fleetms.VehicleInspection.InspectionFormVehicle
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
