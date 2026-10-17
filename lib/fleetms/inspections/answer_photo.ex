defmodule Fleetms.Inspections.AnswerPhoto do
  @moduledoc """
  A photo captured against an inspection answer, embedded on `Answer`. Only the storage
  keys are kept — a display image and its thumbnail — so the evidence stays with the
  submitted inspection. Deleting the inspection removes the stored objects.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :image_key, :string, public?: true, allow_nil?: false
    attribute :thumbnail_key, :string, public?: true, allow_nil?: false
  end
end
