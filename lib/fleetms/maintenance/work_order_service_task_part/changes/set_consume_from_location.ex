defmodule Fleetms.Maintenance.WorkOrderServiceTaskPart.Changes.SetConsumeFromLocation do
  @moduledoc """
  Derives `consume_stock?` from whether a stock location was chosen for the line.

  Choosing an inventory location for a part means "draw this quantity from that
  location" — so completing the work order should consume it. A part with no location
  (e.g. one bought specifically for the job) is only recorded, not drawn from stock.

  Only runs when the `inventory_location_id` argument was actually supplied (which the
  work-order form always does), so a programmatic update that omits it won't flip the
  flag.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :inventory_location_id) do
      {:ok, location_id} ->
        Ash.Changeset.force_change_attribute(changeset, :consume_stock?, not is_nil(location_id))

      :error ->
        changeset
    end
  end
end
