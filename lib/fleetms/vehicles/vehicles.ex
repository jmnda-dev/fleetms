defmodule Fleetms.Vehicles do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Vehicles.VehicleListFilter

    resource Fleetms.Vehicles.Vehicle do
      define :list_vehicles,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :filters]
    end

    resource Fleetms.Vehicles.VehicleMake
    resource Fleetms.Vehicles.VehicleModel
    resource Fleetms.Vehicles.VehiclePhoto
    resource Fleetms.Vehicles.VehicleDocument
    resource Fleetms.Vehicles.VehicleGroup
    resource Fleetms.Vehicles.VehicleEngineSpec
    resource Fleetms.Vehicles.VehicleDrivetrainSpec

    resource Fleetms.Vehicles.VehicleAssignment do
      define :list_vehicle_assignments,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]
    end

    resource Fleetms.Vehicles.VehicleOtherSpec
    resource Fleetms.Vehicles.VehiclePerformanceSpec
    resource Fleetms.Vehicles.VehicleReminderPurpose

    resource Fleetms.Vehicles.VehicleGeneralReminder do
      define :list_vehicle_general_reminders,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]
    end

    resource Fleetms.Service.ServiceGroupVehicle
    resource Fleetms.Inspection.InspectionFormVehicle
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
