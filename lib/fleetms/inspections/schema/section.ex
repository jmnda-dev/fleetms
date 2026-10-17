defmodule Fleetms.Inspections.Schema.Section do
  @moduledoc """
  A titled group of items within an inspection form. Sections can themselves be
  conditionally shown via `visible_when`.

  Embedded in `Fleetms.Inspections.Schema`.
  """
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.Schema.Item

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :id, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 64
    end

    attribute :title, :string do
      public? true
      constraints max_length: 200
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :visible_when, :map, public?: true

    attribute :items, {:array, Item} do
      public? true
      allow_nil? false
      default []
    end
  end
end
