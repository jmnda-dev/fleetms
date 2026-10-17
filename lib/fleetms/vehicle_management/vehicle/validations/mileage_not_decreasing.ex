defmodule Fleetms.VehicleManagement.Vehicle.Validations.MileageNotDecreasing do
  @moduledoc """
  Rejects an update that lowers a vehicle's odometer reading. Mileage only ever
  goes up, so a smaller value is almost always a typo; allowing it would corrupt
  service-reminder math down the line.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    new = Ash.Changeset.get_attribute(changeset, :mileage)
    current = Ash.Changeset.get_data(changeset, :mileage)

    if is_nil(new) or is_nil(current) or Decimal.compare(new, current) != :lt do
      :ok
    else
      {:error,
       field: :mileage,
       message: "cannot be less than the current mileage (%{current})",
       vars: [current: Decimal.to_string(current, :normal)]}
    end
  end

  @impl true
  def atomic(_changeset, _opts, _context) do
    # Compares the new value against the stored value; runs in the action body.
    {:not_atomic, "mileage validation compares against the current record value"}
  end
end
