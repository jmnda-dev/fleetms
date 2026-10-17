defmodule Fleetms.VehicleManagement.VehicleAssignment.Validations.NoOverlappingAssignment do
  @moduledoc """
  Rejects an assignment whose period overlaps another assignment for the same
  vehicle. A vehicle can only be in one person's hands at a time.

  Periods are half-open: an assignment that ends exactly when another starts does
  not overlap. An unset `end_datetime` means open-ended (extends to infinity), so
  it overlaps anything starting at or after its start. The current record is
  excluded on update so editing an assignment doesn't clash with itself.
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias Fleetms.VehicleManagement.VehicleAssignment

  @impl true
  def validate(changeset, _opts, context) do
    vehicle_id = Ash.Changeset.get_attribute(changeset, :vehicle_id)
    start = Ash.Changeset.get_attribute(changeset, :start_datetime)
    finish = Ash.Changeset.get_attribute(changeset, :end_datetime)

    # Let the required-field/range validations handle missing inputs.
    if is_nil(vehicle_id) or is_nil(start) do
      :ok
    else
      if overlapping?(vehicle_id, start, finish, changeset.data.id, context) do
        {:error,
         field: :start_datetime, message: "overlaps an existing assignment for this vehicle"}
      else
        :ok
      end
    end
  end

  defp overlapping?(vehicle_id, start, finish, current_id, context) do
    VehicleAssignment
    |> Ash.Query.filter(vehicle_id == ^vehicle_id)
    |> exclude_self(current_id)
    |> filter_overlap(start, finish)
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: context.tenant, actor: context.actor, authorize?: false)
    |> Kernel.!=([])
  end

  defp exclude_self(query, nil), do: query
  defp exclude_self(query, id), do: Ash.Query.filter(query, id != ^id)

  # An existing row overlaps when it starts before our end (or we have no end) and
  # ends after our start (or it has no end).
  defp filter_overlap(query, start, nil) do
    Ash.Query.filter(query, is_nil(end_datetime) or end_datetime > ^start)
  end

  defp filter_overlap(query, start, finish) do
    Ash.Query.filter(
      query,
      start_datetime < ^finish and (is_nil(end_datetime) or end_datetime > ^start)
    )
  end
end
