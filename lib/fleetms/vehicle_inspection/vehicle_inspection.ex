defmodule Fleetms.VehicleInspection do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.VehicleInspection.InspectionForm
    resource Fleetms.VehicleInspection.InspectionFormVehicle
    resource Fleetms.VehicleInspection.Form.NumberInput
    resource Fleetms.VehicleInspection.Form.RadioInput
    resource Fleetms.VehicleInspection.Form.DropdownInput
    resource Fleetms.VehicleInspection.Form.SignatureInput
    resource Fleetms.VehicleInspection.Form.TextInput
    resource Fleetms.VehicleInspection.InspectionSubmission
    resource Fleetms.VehicleInspection.RadioInputValue
    resource Fleetms.VehicleInspection.DropdownInputValue
    resource Fleetms.VehicleInspection.NumberInputValue
    resource Fleetms.VehicleInspection.SignatureInputValue
    resource Fleetms.VehicleInspection.TextInputValue
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
