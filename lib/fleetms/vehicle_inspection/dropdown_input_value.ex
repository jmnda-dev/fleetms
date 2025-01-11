defmodule Fleetms.VehicleInspection.DropdownInputValue do
  use Ash.Resource,
    domain: Fleetms.VehicleInspection,
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
      default :dropdown_input_type
      writable? false
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:Pass, :Fail, :"Not-Applicable"]
    end

    attribute :selected_option, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
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
    table "dropdown_input_values"
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

      argument :fail_options, {:array, :string} do
        allow_nil? false
        default []
      end

      argument :options, {:array, :string} do
        allow_nil? false
      end

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
        selected_option = Ash.Changeset.get_attribute(changeset, :selected_option)
        fail_options = Ash.Changeset.get_argument_or_attribute(changeset, :fail_options)

        comment_on_fail =
          Ash.Changeset.get_argument_or_attribute(changeset, :comment_required_on_fail)

        comment_on_pass =
          Ash.Changeset.get_argument_or_attribute(changeset, :comment_required_on_pass)

        if not is_nil(selected_option) and not is_nil(fail_options) and
             selected_option in fail_options do
          Ash.Changeset.force_change_attribute(changeset, :status, :Fail)
        else
          Ash.Changeset.force_change_attribute(changeset, :status, :Pass)
        end
        |> validate_comment_required(selected_option, comment_on_fail, comment_on_pass)
      end
    end

    update :update do
      primary? true
      require_atomic? false
      accept :*

      argument :inspection_submission_id, :uuid

      # argument :status, :atom, allow_nil?: false

      change manage_relationship(:inspection_submission_id, :inspection_submission,
               type: :append_and_remove
             )
    end
  end

  multitenancy do
    strategy :context
  end

  defp validate_comment_required(changeset, selected_option, comment_on_fail, comment_on_pass) do
    comments = Ash.Changeset.get_argument_or_attribute(changeset, :comments)
    status = Ash.Changeset.get_attribute(changeset, :status)

    cond do
      is_nil(selected_option) ->
        changeset

      not is_nil(selected_option) and comment_on_fail and comment_on_pass ->
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
