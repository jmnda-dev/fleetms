defmodule Fleetms.Inspections.Answer do
  @moduledoc """
  One graded answer within a submitted inspection, embedded on `Inspection`.

  Records what was answered for an item (`value`, or `values` for multi-select,
  plus an optional `comment`) alongside the server-computed `status`. Answers are
  snapshotted with the inspection, so they stay readable even as the form evolves.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :item_id, :string, public?: true, allow_nil?: false

    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      description: "Snapshot of the item's type."

    attribute :value, :string, public?: true
    attribute :values, {:array, :string}, public?: true
    attribute :comment, :string, public?: true, constraints: [max_length: 2000]

    attribute :photos, {:array, Fleetms.Inspections.AnswerPhoto} do
      public? true
      default []
      description "Photo evidence captured for this item (storage keys), snapshotted."
    end

    attribute :signature, Fleetms.Inspections.AnswerPhoto do
      public? true
      description "A captured signature image (storage keys), for signature items."
    end

    attribute :status, :atom do
      public? true
      allow_nil? false
      constraints one_of: [:pass, :fail, :na, :answered, :skipped]

      description "Computed on submit: pass/fail/na for gradable items, answered for informational ones, skipped when unanswered."
    end
  end
end
