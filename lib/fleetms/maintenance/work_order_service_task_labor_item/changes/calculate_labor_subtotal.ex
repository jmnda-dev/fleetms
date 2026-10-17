defmodule Fleetms.Maintenance.WorkOrderServiceTaskLaborItem.Changes.CalculateLaborSubtotal do
  @moduledoc """
  Derives a labour line's `subtotal` on write and freezes it: `hours × hourly_rate`
  for technician labour, the `flat_cost` for vendor labour. When the inputs for the
  line's type are absent there is no subtotal.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    labor_type = Ash.Changeset.get_attribute(changeset, :labor_type)
    Ash.Changeset.force_change_attribute(changeset, :subtotal, subtotal(changeset, labor_type))
  end

  defp subtotal(changeset, :technician) do
    rate = Ash.Changeset.get_attribute(changeset, :hourly_rate)
    hours = Ash.Changeset.get_attribute(changeset, :hours)

    case {rate, hours} do
      {%Money{} = rate, %Decimal{} = hours} -> Money.mult!(rate, hours)
      _ -> nil
    end
  end

  defp subtotal(changeset, :vendor) do
    Ash.Changeset.get_attribute(changeset, :flat_cost)
  end

  defp subtotal(_changeset, _labor_type), do: nil
end
