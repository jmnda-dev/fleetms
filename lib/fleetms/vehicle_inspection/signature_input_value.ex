defmodule Fleetms.VehicleInspection.SignatureInputValue do
  use Ash.Resource,
    domain: Fleetms.VehicleInspection,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :role, :string do
      allow_nil? true
      public? true
    end

    # TODO: Convert this from base64 string to a PNG and store a URL to the image
    attribute :encoded_image, :string do
      allow_nil? false
      public? true
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
    table "signature_input_values"
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

      argument :label, :string

      argument :help_text, :string

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
