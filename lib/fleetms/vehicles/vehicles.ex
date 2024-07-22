defmodule Fleetms.Vehicles do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Vehicles.Vehicle
    resource Fleetms.Vehicles.VehicleMake
    resource Fleetms.Vehicles.VehicleModel
    resource Fleetms.Vehicles.VehiclePhoto
    resource Fleetms.Vehicles.VehicleDocument
    resource Fleetms.Vehicles.VehicleGroup
    resource Fleetms.Vehicles.VehicleEngineSpec
    resource Fleetms.Vehicles.VehicleDrivetrainSpec
    resource Fleetms.Vehicles.VehicleAssignment
    resource Fleetms.Vehicles.VehicleOtherSpec
    resource Fleetms.Vehicles.VehiclePerformanceSpec
    resource Fleetms.Vehicles.VehicleReminderPurpose
    resource Fleetms.Vehicles.VehicleGeneralReminder
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
