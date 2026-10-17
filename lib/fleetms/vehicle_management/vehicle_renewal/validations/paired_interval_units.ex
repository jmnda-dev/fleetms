defmodule Fleetms.VehicleManagement.VehicleRenewal.Validations.PairedIntervalUnits do
  @moduledoc """
  Each amount/unit pair must be given together or not at all: a recurrence amount
  needs a recurrence unit, and a notify-before amount needs a notify-before unit
  (and vice versa). Either pair may be omitted entirely (no recurrence / no
  "Due Soon" lead time).
  """
  use Ash.Resource.Validation

  @pairs [
    {:recurrence_interval, :recurrence_unit},
    {:notify_before, :notify_before_unit}
  ]

  @impl true
  def validate(changeset, _opts, _context) do
    Enum.reduce_while(@pairs, :ok, fn {amount_field, unit_field}, :ok ->
      amount = Ash.Changeset.get_attribute(changeset, amount_field)
      unit = Ash.Changeset.get_attribute(changeset, unit_field)

      cond do
        not is_nil(amount) and is_nil(unit) ->
          {:halt, {:error, field: unit_field, message: "is required when an amount is given"}}

        is_nil(amount) and not is_nil(unit) ->
          {:halt, {:error, field: amount_field, message: "is required when a unit is given"}}

        true ->
          {:cont, :ok}
      end
    end)
  end
end
