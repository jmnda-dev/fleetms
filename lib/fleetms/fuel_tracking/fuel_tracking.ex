defmodule Fleetms.FuelTracking do
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Fleetms.FuelTracking.FuelHistory do
      define :list_fuel_histories,
        action: :list,
        args: [:paginate_sort_opts, :search_query, :advanced_filter_params]
    end

    resource Fleetms.FuelTracking.FuelHistoryPhoto
  end

  authorization do
    authorize :always
  end

  admin do
    show? true
  end
end
