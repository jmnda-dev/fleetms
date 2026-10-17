defmodule Fleetms.Maintenance.WorkOrderServiceTaskPart.Changes.CalculateSubtotal do
  @moduledoc """
  Sets `subtotal` to `unit_cost × quantity` whenever a work-order part line is
  written, so the charged amount is frozen at write time rather than recomputed
  from the (mutable) catalogue price. With no unit cost there is no subtotal.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    unit_cost = Ash.Changeset.get_attribute(changeset, :unit_cost)
    quantity = Ash.Changeset.get_attribute(changeset, :quantity)

    case {unit_cost, quantity} do
      {%Money{} = unit_cost, %Decimal{} = quantity} ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :subtotal,
          Money.mult!(unit_cost, quantity)
        )

      _ ->
        Ash.Changeset.force_change_attribute(changeset, :subtotal, nil)
    end
  end
end
