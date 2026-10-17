defmodule Fleetms.Inspections.Schema.Settings do
  @moduledoc """
  Form-wide settings that shape how an inspection is scored and filled.

  Embedded in `Fleetms.Inspections.Schema`.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
    default_accept :*
  end

  attributes do
    attribute :pass_policy, :atom do
      public? true
      allow_nil? false
      default :all_pass
      constraints one_of: [:all_pass, :threshold]

      description "How the overall result is computed: any failure fails (:all_pass), or up to `fail_threshold` failures still pass (:threshold)."
    end

    attribute :fail_threshold, :integer do
      public? true
      constraints min: 0

      description "In :threshold mode, the maximum number of failed items still counted as an overall pass."
    end

    attribute :require_signature, :boolean do
      public? true
      allow_nil? false
      default false
      description "Require at least one signature item to be answered before submitting."
    end

    attribute :allow_partial_save, :boolean do
      public? true
      allow_nil? false
      default true
      description "Allow the filler to save an in-progress inspection as a draft."
    end

    attribute :meter_unit, :string do
      public? true
      allow_nil? false
      default "km"
      constraints max_length: 12
      description "Default unit shown for meter/number items (e.g. \"km\", \"mi\")."
    end
  end
end
