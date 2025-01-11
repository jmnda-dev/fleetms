defmodule Fleetms.VehicleManagement.VehicleAssignment.Validations.ValidateStartAndEndDatetime do
  use Ash.Resource.Validation

  def validate(changeset, _opts, _context) do
    start_datetime = Ash.Changeset.get_attribute(changeset, :start_datetime)
    end_datetime = Ash.Changeset.get_attribute(changeset, :end_datetime)

    if is_nil(end_datetime) do
      :ok
    else
      case DateTime.compare(start_datetime, end_datetime) do
        :gt ->
          {:error,
           field: :start_datetime,
           message: "Start Date and Time must be less that the End Date and Time"}

        :lt ->
          :ok
      end
    end
  end
end
