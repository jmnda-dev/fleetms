defmodule Fleetms.VehicleManagement.VehicleAssignment.Validations.ValidDatetimeRange do
  @moduledoc """
  Ensures an assignment's `end_datetime`, when set, is not before its
  `start_datetime`. An unset end means the assignment is still open-ended, which
  is always valid.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    start = Ash.Changeset.get_attribute(changeset, :start_datetime)
    finish = Ash.Changeset.get_attribute(changeset, :end_datetime)

    cond do
      is_nil(start) or is_nil(finish) ->
        :ok

      DateTime.compare(finish, start) == :lt ->
        {:error, field: :end_datetime, message: "must be on or after the start date and time"}

      true ->
        :ok
    end
  end
end
