defmodule Fleetms.Inspection.RadioInputValue do
  use Ash.Resource,
    domain: Fleetms.Inspection,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      default :radio_input_type
      writable? false
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:Pass, :Fail, :"Not-Applicable"]
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
    belongs_to :inspection_submission, Fleetms.Inspection.InspectionSubmission do
      allow_nil? false
    end
  end

  postgres do
    table "radio_input_values"
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

      argument :pass_label, :string do
        allow_nil? false
      end

      argument :fail_label, :string do
        allow_nil? false
      end

      argument :allow_na, :boolean

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
        status = Ash.Changeset.get_attribute(changeset, :status)
        comments = Ash.Changeset.get_attribute(changeset, :comments)

        comment_on_pass =
          Ash.Changeset.get_argument_or_attribute(changeset, :comment_required_on_pass)

        comment_on_fail =
          Ash.Changeset.get_argument_or_attribute(changeset, :comment_required_on_fail)

        cond do
          is_nil(status) ->
            changeset

          is_nil(comments) and comment_on_fail and comment_on_pass ->
            Ash.Changeset.add_error(changeset,
              field: :comments,
              message: "Comments are required whether item has Passed or Failed"
            )

          is_nil(comments) and comment_on_fail and status == :Fail ->
            Ash.Changeset.add_error(changeset,
              field: :comments,
              message: "Comments are required when item has Failed"
            )

          is_nil(comments) and comment_on_pass and status == :Pass ->
            Ash.Changeset.add_error(changeset,
              field: :comments,
              message: "Comments are required item has Passed"
            )

          true ->
            changeset
        end
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
end
