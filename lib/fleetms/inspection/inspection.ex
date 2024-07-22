defmodule Fleetms.Inspection do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.Inspection.InspectionForm
    resource Fleetms.Inspection.InspectionFormVehicle
    resource Fleetms.Inspection.Form.NumberInput
    resource Fleetms.Inspection.Form.RadioInput
    resource Fleetms.Inspection.Form.DropdownInput
    resource Fleetms.Inspection.Form.SignatureInput
    resource Fleetms.Inspection.Form.TextInput
    resource Fleetms.Inspection.InspectionSubmission
    resource Fleetms.Inspection.RadioInputValue
    resource Fleetms.Inspection.DropdownInputValue
    resource Fleetms.Inspection.NumberInputValue
    resource Fleetms.Inspection.SignatureInputValue
    resource Fleetms.Inspection.TextInputValue
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
