defmodule Fleetms.Inspections.Schema.Workflow do
  @moduledoc """
  One automation attached to an inspection form: **when** a trigger fires on a
  submitted inspection, **then** run its actions.

  Like items, the shape is a tagged union both ways: `trigger` is a single union
  over the four trigger variants, and `actions` is an array-union over the action
  variants — so `workflow.trigger.type` and `action.type` are the source of truth
  for what each is. `:map_with_tag` storage keeps the persisted JSON flat, matching
  what the builder emits and the engine (`Fleetms.Inspections.Workflows`) consumes.

  Adding a trigger or action kind is one union line here plus its embedded module
  in `workflow_triggers.ex` / `workflow_actions.ex` — no migration.
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
      description "Stable key assigned by the builder."
    end

    attribute :name, :string do
      public? true
      constraints max_length: 120
      description "Optional human label shown in the builder."
    end

    attribute :enabled, :boolean do
      public? true
      allow_nil? false
      default true
      description "Disabled workflows are kept but skipped at run time."
    end

    attribute :trigger, :union do
      public? true
      allow_nil? false

      constraints types: [
                    inspection_submitted: [
                      type: Schema.InspectionSubmittedTrigger,
                      tag: :type,
                      tag_value: :inspection_submitted
                    ],
                    inspection_failed: [
                      type: Schema.InspectionFailedTrigger,
                      tag: :type,
                      tag_value: :inspection_failed
                    ],
                    any_item_failed: [
                      type: Schema.AnyItemFailedTrigger,
                      tag: :type,
                      tag_value: :any_item_failed
                    ],
                    item_failed: [
                      type: Schema.ItemFailedTrigger,
                      tag: :type,
                      tag_value: :item_failed
                    ]
                  ],
                  storage: :map_with_tag
    end

    attribute :actions, {:array, :union} do
      public? true
      allow_nil? false
      default []

      constraints items: [
                    types: [
                      open_issue: [
                        type: Schema.OpenIssueAction,
                        tag: :type,
                        tag_value: :open_issue
                      ],
                      notify: [type: Schema.NotifyAction, tag: :type, tag_value: :notify]
                    ],
                    storage: :map_with_tag
                  ]
    end
  end
end
