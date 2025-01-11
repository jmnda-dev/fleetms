defmodule Fleetms.VehicleManagement.VehicleListFilter do
  use Ash.Resource,
    domain: Fleetms.VehicleManagement,
    data_layer: Ash.DataLayer.Simple

  @attributes [
    :make,
    :model,
    :year_min,
    :year_max,
    :mileage_min,
    :mileage_max,
    :statuses,
    :types,
    :categories
  ]

  def get_attributes, do: @attributes

  resource do
    require_primary_key? false
  end

  attributes do
    attribute :make, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 50
    end

    attribute :model, :uuid do
      allow_nil? true
      public? true
    end

    attribute :year_min, :integer do
      allow_nil? true
      public? true
      constraints min: 1900
    end

    attribute :year_max, :integer do
      allow_nil? true
      public? true
      constraints min: 1900
    end

    attribute :mileage_min, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :mileage_max, :integer do
      allow_nil? true
      public? true
      constraints min: 0, max: 999_999_999
    end

    attribute :statuses, {:array, :atom} do
      allow_nil? true
      public? true

      constraints items: [
                    one_of: Fleetms.Enums.vehicle_statuses()
                  ]
    end

    attribute :types, {:array, :atom} do
      allow_nil? true
      public? true

      constraints items: [
                    one_of: Fleetms.Enums.vehicle_types()
                  ]
    end

    attribute :categories, {:array, :atom} do
      allow_nil? true
      public? true

      constraints items: [
                    one_of: Fleetms.Enums.vehicle_categories()
                  ]
    end
  end

  actions do
    action :to_params, :map do
      argument :struct, :struct, constraints: [instance_of: __MODULE__]

      run fn input, _context ->
        params =
          Map.take(input.arguments.struct, @attributes)
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)
          |> Enum.into(%{})

        {:ok, params}
      end
    end

    create :validate do
      accept :*
    end
  end

  code_interface do
    define :validate
    define :to_params, args: [:struct]
  end
end
