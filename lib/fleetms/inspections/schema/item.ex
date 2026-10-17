defmodule Fleetms.Inspections.Schema.Item do
  @moduledoc """
  A single question/field in an inspection form.

  The common envelope (id, label, help text, required, conditional visibility)
  lives here; everything type-specific lives in `config`, a **tagged union** over
  the ten item-config variants in `Fleetms.Inspections.Schema.*Config`. The
  union's `:type` tag is the single source of truth for the item's kind, so an
  item's type is read as `item.config.type` (an `%Ash.Union{}`).

  `:map_with_tag` storage keeps the persisted JSON flat — `%{"type" => "pass_fail",
  "pass_label" => "Pass", ...}` — which is exactly the shape the form builder
  emits and the fill renderer consumes.
  """
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.Schema

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :id, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 64

      description "Stable key assigned by the builder. Answers and conditions reference items by this."
    end

    attribute :label, :string do
      public? true
      constraints max_length: 200
    end

    attribute :help_text, :string do
      public? true
      constraints max_length: 500
    end

    attribute :required, :boolean do
      public? true
      allow_nil? false
      default false
    end

    # A serializable predicate tree deciding whether this item is shown, evaluated
    # against other items' answers. Kept as a loose map for now; typed in the
    # conditional-logic phase.
    attribute :visible_when, :map, public?: true

    attribute :config, :union do
      public? true
      allow_nil? false

      constraints types: [
                    pass_fail: [type: Schema.PassFailConfig, tag: :type, tag_value: :pass_fail],
                    number: [type: Schema.NumberConfig, tag: :type, tag_value: :number],
                    meter: [type: Schema.MeterConfig, tag: :type, tag_value: :meter],
                    single_select: [
                      type: Schema.SingleSelectConfig,
                      tag: :type,
                      tag_value: :single_select
                    ],
                    multi_select: [
                      type: Schema.MultiSelectConfig,
                      tag: :type,
                      tag_value: :multi_select
                    ],
                    text: [type: Schema.TextConfig, tag: :type, tag_value: :text],
                    date: [type: Schema.DateConfig, tag: :type, tag_value: :date],
                    photo: [type: Schema.PhotoConfig, tag: :type, tag_value: :photo],
                    signature: [type: Schema.SignatureConfig, tag: :type, tag_value: :signature],
                    instruction: [
                      type: Schema.InstructionConfig,
                      tag: :type,
                      tag_value: :instruction
                    ]
                  ],
                  storage: :map_with_tag
    end
  end
end
