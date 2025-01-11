defmodule Fleetms.VehicleManagement.Vehicle.Validations.MileageIsGreaterOrEqualToCurrent do
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    current_mileage_value = Ash.Changeset.get_data(changeset, :mileage)
    new_mileage_value = Ash.Changeset.get_attribute(changeset, :mileage)

    if Ash.Changeset.changing_attribute?(changeset, :mileage) do
      if mileage_update_valid?(new_mileage_value, current_mileage_value) do
        :ok
      else
        {:error, field: :mileage, message: "Mileage can not be less than current value"}
      end
    else
      :ok
    end
  end

  defp mileage_update_valid?(new_mileage_value, old_mileage_value) do
    IO.inspect(Decimal.compare(new_mileage_value, old_mileage_value), label: "MILEAGE COMP")
    if Decimal.compare(new_mileage_value, old_mileage_value) in [:eq, :gt], do: true, else: false
  end
end
