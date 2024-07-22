defmodule Fleetms.Vehicles.VehicleAssignment.Changes.SetStatus do
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    current_datetime = DateTime.utc_now()

    start_datetime = Ash.Changeset.get_attribute(changeset, :start_datetime)
    end_datetime = Ash.Changeset.get_attribute(changeset, :end_datetime)

    case DateTime.compare(start_datetime, current_datetime) do
      :gt ->
        Ash.Changeset.force_change_attribute(changeset, :status, :Upcoming)

      :lt ->
        cond do
          is_nil(end_datetime) or
              (not is_nil(end_datetime) and
                 DateTime.compare(current_datetime, end_datetime) == :lt) ->
            Ash.Changeset.force_change_attribute(changeset, :status, :"In-progress")

          true ->
            Ash.Changeset.force_change_attribute(changeset, :status, :Past)
        end
    end
  end
end
