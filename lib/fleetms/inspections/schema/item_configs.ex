# The type-specific configuration for each kind of inspection item. Every module
# here is an embedded resource and a member of the `config` union on
# `Fleetms.Inspections.Schema.Item` — see that module for how they are wired
# together with a `:type` discriminator tag.
#
# Each config declares its own shape and, where relevant, what makes an answer a
# *failure* (which drives the overall result and workflow triggers). Adding a new
# item type is: add a module here + one line to the union in `Item`. No migration —
# the whole schema lives in a single jsonb column.

defmodule Fleetms.Inspections.Schema.Option do
  @moduledoc "A selectable choice for single/multi-select items. `fail?` marks the choice as a failing answer."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :value, :string,
      public?: true,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 100]

    attribute :label, :string,
      public?: true,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 100]

    attribute :fail?, :boolean, public?: true, allow_nil?: false, default: false
  end
end

defmodule Fleetms.Inspections.Schema.PassFailConfig do
  @moduledoc "Pass/Fail (optionally N/A) — the core inspection check. Failure = the fail option is chosen."
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.EventRule

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :pass_fail,
      constraints: [one_of: [:pass_fail]]

    attribute :pass_label, :string,
      public?: true,
      allow_nil?: false,
      default: "Pass",
      constraints: [max_length: 50]

    attribute :fail_label, :string,
      public?: true,
      allow_nil?: false,
      default: "Fail",
      constraints: [max_length: 50]

    attribute :allow_na, :boolean, public?: true, allow_nil?: false, default: true
    attribute :comment_on, EventRule, public?: true, allow_nil?: false, default: :never
    attribute :photo_on, EventRule, public?: true, allow_nil?: false, default: :never
  end
end

defmodule Fleetms.Inspections.Schema.NumberConfig do
  @moduledoc "A numeric reading with an optional pass range. Failure = value falls outside [pass_min, pass_max]."
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.EventRule

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  validations do
    validate compare(:pass_min, less_than_or_equal_to: :pass_max) do
      where [present(:pass_min), present(:pass_max)]
      message "pass_min must be less than or equal to pass_max"
    end
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :number,
      constraints: [one_of: [:number]]

    attribute :unit, :string, public?: true, constraints: [max_length: 12]

    attribute :decimals, :integer,
      public?: true,
      allow_nil?: false,
      default: 0,
      constraints: [min: 0, max: 6]

    attribute :min, :decimal, public?: true, description: "Hard lower bound on entry (optional)."
    attribute :max, :decimal, public?: true, description: "Hard upper bound on entry (optional)."

    attribute :pass_min, :decimal,
      public?: true,
      description: "Inclusive lower bound of the passing range."

    attribute :pass_max, :decimal,
      public?: true,
      description: "Inclusive upper bound of the passing range."

    attribute :comment_on, EventRule, public?: true, allow_nil?: false, default: :never
    attribute :photo_on, EventRule, public?: true, allow_nil?: false, default: :never
  end
end

defmodule Fleetms.Inspections.Schema.MeterConfig do
  @moduledoc "An odometer/hour reading that can write back to the vehicle. Failure = a decreasing reading when must_increase is set."
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.EventRule

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :meter,
      constraints: [one_of: [:meter]]

    attribute :unit, :string, public?: true, constraints: [max_length: 12]
    attribute :write_to_vehicle, :boolean, public?: true, allow_nil?: false, default: true
    attribute :must_increase, :boolean, public?: true, allow_nil?: false, default: true
    attribute :comment_on, EventRule, public?: true, allow_nil?: false, default: :never
  end
end

defmodule Fleetms.Inspections.Schema.SingleSelectConfig do
  @moduledoc "Pick one of a list of options. Failure = the chosen option is flagged as failing."
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.EventRule
  alias Fleetms.Inspections.Schema.Option

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :single_select,
      constraints: [one_of: [:single_select]]

    attribute :display, :atom,
      public?: true,
      allow_nil?: false,
      default: :dropdown,
      constraints: [one_of: [:dropdown, :radio]]

    attribute :options, {:array, Option}, public?: true, allow_nil?: false, default: []
    attribute :comment_on, EventRule, public?: true, allow_nil?: false, default: :never
    attribute :photo_on, EventRule, public?: true, allow_nil?: false, default: :never
  end
end

defmodule Fleetms.Inspections.Schema.MultiSelectConfig do
  @moduledoc "Pick any number of options (checkboxes). Failure = any chosen option is flagged as failing."
  use Ash.Resource, data_layer: :embedded

  alias Fleetms.Inspections.EventRule
  alias Fleetms.Inspections.Schema.Option

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :multi_select,
      constraints: [one_of: [:multi_select]]

    attribute :options, {:array, Option}, public?: true, allow_nil?: false, default: []

    attribute :min_selected, :integer,
      public?: true,
      allow_nil?: false,
      default: 0,
      constraints: [min: 0]

    attribute :max_selected, :integer, public?: true, constraints: [min: 1]
    attribute :fail_if_any_fail_option, :boolean, public?: true, allow_nil?: false, default: true
    attribute :comment_on, EventRule, public?: true, allow_nil?: false, default: :never
  end
end

defmodule Fleetms.Inspections.Schema.TextConfig do
  @moduledoc "Free-text notes. Informational — never fails on its own; can be marked required on the item."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :text,
      constraints: [one_of: [:text]]

    attribute :multiline, :boolean, public?: true, allow_nil?: false, default: true
    attribute :max_length, :integer, public?: true, constraints: [min: 1, max: 10_000]
  end
end

defmodule Fleetms.Inspections.Schema.DateConfig do
  @moduledoc "Capture a date/datetime. Failure = the configured past/future rule is violated (e.g. an expiry in the past)."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :date,
      constraints: [one_of: [:date]]

    attribute :mode, :atom,
      public?: true,
      allow_nil?: false,
      default: :date,
      constraints: [one_of: [:date, :datetime]]

    attribute :fail_if_past, :boolean, public?: true, allow_nil?: false, default: false
    attribute :fail_if_future, :boolean, public?: true, allow_nil?: false, default: false
  end
end

defmodule Fleetms.Inspections.Schema.PhotoConfig do
  @moduledoc "Standalone photo evidence capture. Informational — does not fail."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :photo,
      constraints: [one_of: [:photo]]

    attribute :min_photos, :integer,
      public?: true,
      allow_nil?: false,
      default: 1,
      constraints: [min: 0, max: 20]

    attribute :max_photos, :integer, public?: true, constraints: [min: 1, max: 20]
  end
end

defmodule Fleetms.Inspections.Schema.SignatureConfig do
  @moduledoc "Capture a signature image. `who` is a semantic label for whose signature is expected."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :signature,
      constraints: [one_of: [:signature]]

    attribute :prompt, :string, public?: true, constraints: [max_length: 200]

    attribute :who, :atom,
      public?: true,
      allow_nil?: false,
      default: :inspector,
      constraints: [one_of: [:inspector, :driver, :reviewer]]
  end
end

defmodule Fleetms.Inspections.Schema.InstructionConfig do
  @moduledoc "Display-only guidance shown during fill. Has no answer and cannot fail."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :type, :atom,
      public?: true,
      allow_nil?: false,
      default: :instruction,
      constraints: [one_of: [:instruction]]

    attribute :body, :string,
      public?: true,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 2000]
  end
end
