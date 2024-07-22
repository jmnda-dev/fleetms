defmodule Fleetms.Dashboard.PartsStats do
  defstruct total_parts: 0, total_inventory_locations: 0

  def get_dashboard_stats(tenant) do
    {:ok, %{total_parts: total, total_inventory_locations: inventory_locations}} =
      Fleetms.Inventory.Part.get_dashboard_stats(tenant)

    %__MODULE__{
      total_parts: total,
      total_inventory_locations: inventory_locations
    }
  end
end
