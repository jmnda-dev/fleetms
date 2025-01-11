defmodule Fleetms.VehicleInspection.TextInputValue do
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
      default :text_input_type
      writable? false
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
    table "text_input_values"
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

      argument :name, :string do
        allow_nil? false
      end

      change manage_relationship(:inspection_submission_id, :inspection_submission,
               type: :append_and_remove
             )
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
