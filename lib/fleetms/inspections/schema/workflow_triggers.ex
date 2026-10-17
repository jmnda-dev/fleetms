# The trigger variants for an inspection workflow — the *when* half of a
# workflow's when→then. Every module here is an embedded resource and a member of
# the `trigger` union on `Fleetms.Inspections.Schema.Workflow` (tagged by `:type`).
#
# A trigger is evaluated against a freshly graded inspection by
# `Fleetms.Inspections.Workflows`; if it fires, the workflow's actions run. Adding
# a new trigger kind is: add a module here + one line to the union in `Workflow`.

defmodule Fleetms.Inspections.Schema.InspectionSubmittedTrigger do
  @moduledoc "Fires on every submission, whatever the outcome (e.g. notify a supervisor of all activity)."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :inspection_submitted,
      constraints: [one_of: [:inspection_submitted]]
  end
end

defmodule Fleetms.Inspections.Schema.InspectionFailedTrigger do
  @moduledoc "Fires when the inspection's overall result is a failure."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :inspection_failed,
      constraints: [one_of: [:inspection_failed]]
  end
end

defmodule Fleetms.Inspections.Schema.AnyItemFailedTrigger do
  @moduledoc "Fires when at least one item failed, even if the overall result still passed under a threshold policy."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :any_item_failed,
      constraints: [one_of: [:any_item_failed]]
  end
end

defmodule Fleetms.Inspections.Schema.ItemFailedTrigger do
  @moduledoc "Fires when one specific item failed. `item_id` references an item in the same form."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :item_failed,
      constraints: [one_of: [:item_failed]]

    attribute :item_id, :string,
      public?: true,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 64]
  end
end
