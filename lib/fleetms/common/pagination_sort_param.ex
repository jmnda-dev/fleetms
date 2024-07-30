defmodule Fleetms.Common.PaginationSortParam do
  @moduledoc """
  A Resource for validating Pagination and Sort params
  """
  use Ash.Resource,
    domain: Fleetms.Common,
    data_layer: Ash.DataLayer.Simple

  attributes do
    attribute :page, :integer, public?: true, default: 1
    attribute :per_page, :integer, public?: true, default: 20
    attribute :sort_by, :atom, public?: true, default: :updated_at

    attribute :sort_order, :atom,
      public?: true,
      default: :desc,
      constraints: [one_of: [:asc, :desc]]
  end

  resource do
    require_primary_key? false
  end

  actions do
    create :validate do
      accept [:page, :per_page, :sort_by, :sort_order]

      argument :per_page_opts, {:array, :integer} do
        description "A list of possible options/values e.g [10, 20 ,30, 50, 100]"
      end

      argument :sort_by_opts, {:array, :atom} do
        description "A list of possible options/values e.g [:created_at, :updated_at, :name]"
      end

      validate one_of(:per_page, arg(:per_page_opts)) do
        description "Validates that the value is in the list of allowed values"
      end

      validate one_of(:sort_by, arg(:sort_by_opts)) do
        description "Validates that the value is in the list of allowed values"
      end
    end
  end

  code_interface do
    define :validate, args: [:per_page_opts, :sort_by_opts]
  end
end
