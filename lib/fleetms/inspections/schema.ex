defmodule Fleetms.Inspections.Schema do
  @moduledoc """
  The whole inspection-form document: settings, an ordered list of sections (each
  with an ordered list of items), and workflows.

  This is the single typed value stored in a jsonb column — as the mutable
  `draft_schema` on `Fleetms.Inspections.InspectionForm` while it is being edited,
  and as the frozen, immutable `schema` snapshot on
  `Fleetms.Inspections.InspectionFormVersion` once published. Because the entire
  document lives in one column, evolving its shape (new item types, new settings)
  needs no database migration; `schema_version` tracks the document *format* for
  any future in-place upcasting.

  Items are validated through the union in `Schema.Item`, and workflows through the
  union in `Schema.Workflow`, so the document is flexible JSON on the outside but
  strictly typed on the way in. `visible_when` conditions remain a loosely typed
  predicate map (evaluated by `Schema`-external code, `Fleetms.Inspections.Condition`).
  """
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.Schema.{Section, Settings, Workflow}

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :schema_version, :integer do
      public? true
      allow_nil? false
      default 1
      description "Version of the document *format*, for future in-place upcasting."
    end

    attribute :settings, Settings do
      public? true
      allow_nil? false
      default %{}
    end

    attribute :sections, {:array, Section} do
      public? true
      allow_nil? false
      default []
    end

    # Form-level automations: when a trigger fires on a submitted inspection, run
    # its actions (open an issue, notify someone). See Schema.Workflow.
    attribute :workflows, {:array, Workflow} do
      public? true
      allow_nil? false
      default []
    end
  end
end
