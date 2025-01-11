defmodule Fleetms.VehicleInspection.NumberInputValue do
  use Ash.Resource,
    domain: Fleetms.VehicleInspection,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
    end

    attribute :pass_range_min, :integer do
      allow_nil? false
      public? true
      default 0
      constraints min: -999_999_999, max: 999_999_999
    end

    attribute :pass_range_max, :integer do
      allow_nil? false
      public? true
      default 999_999_999
      constraints min: -999_999_999, max: 999_999_999
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      default :number_input_type
      writable? false
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:Pass, :Fail, :"Not-Applicable"]
    end

    attribute :value, :integer do
      allow_nil? false
      public? true
      constraints min: -999_999_999, max: 999_999_999
    end

    attribute :comments, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :inspection_submission, Fleetms.VehicleInspection.InspectionSubmission do
      allow_nil? false
    end
  end

  postgres do
    table "number_input_values"
    repo Fleetms.Repo

    references do
      reference :inspection_submission, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      argument :inspection_submission_id, :uuid

      argument :help_text, :string

      argument :comment_required_on_pass, :boolean do
        allow_nil? false
      end

      argument :comment_required_on_fail, :boolean do
        allow_nil? false
      end

      change manage_relationship(:inspection_submission_id, :inspection_submission,
               type: :append_and_remove
             )

      change fn changeset, _context ->
        pass_range_min = Ash.Changeset.get_argument_or_attribute(changeset, :pass_range_min)
        pass_range_max = Ash.Changeset.get_argument_or_attribute(changeset, :pass_range_max)
        value = Ash.Changeset.get_attribute(changeset, :value)

        comment_on_fail =
          Ash.Changeset.get_argument_or_attribute(changeset, :comment_required_on_fail)

        comment_on_pass =
          Ash.Changeset.get_argument_or_attribute(changeset, :comment_required_on_pass)

        cond do
          is_nil(value) ->
            changeset

          value >= pass_range_min && value <= pass_range_max ->
            Ash.Changeset.force_change_attribute(changeset, :status, :Pass)

          value < pass_range_min || value > pass_range_max ->
            Ash.Changeset.force_change_attribute(changeset, :status, :Fail)

          true ->
            changeset
        end
        |> validate_comment_required(value, comment_on_fail, comment_on_pass)
      end
    end

    update :update do
      primary? true
      require_atomic? false
      accept :*
      argument :inspection_submission_id, :uuid

      change manage_relationship(:inspection_submission_id, :inspection_submission,
               type: :append_and_remove
             )
    end
  end

  multitenancy do
    strategy :context
  end

  defp validate_comment_required(changeset, value, comment_on_fail, comment_on_pass) do
    comments = Ash.Changeset.get_argument_or_attribute(changeset, :comments)
    status = Ash.Changeset.get_attribute(changeset, :status)

    cond do
      is_nil(value) ->
        changeset

      not is_nil(value) and comment_on_fail and comment_on_pass ->
        Ash.Changeset.add_error(changeset, field: :comments, message: "Comments are required")

      status == :Pass and comment_on_pass and is_nil(comments) ->
        Ash.Changeset.add_error(changeset, field: :comments, message: "Comments are required")

      status == :Fail and comment_on_fail and is_nil(comments) ->
        Ash.Changeset.add_error(changeset, field: :comments, message: "Comments are required")

      true ->
        changeset
    end
  end
end
