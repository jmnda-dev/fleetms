defmodule Fleetms.VehicleInspection.Form.SignatureInput do
  use Ash.Resource,
    domain: Fleetms.VehicleInspection,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      writable? false
      constraints one_of: [:signature_input_type]
      default :signature_input_type
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 50
    end

    attribute :help_text, :string do
      allow_nil? true
      public? true
      constraints min_length: 0, max_length: 500
    end

    attribute :required, :boolean do
      allow_nil? false
      public? true
      default true
    end
  end

  relationships do
    belongs_to :inspection_form, Fleetms.VehicleInspection.InspectionForm
  end

  postgres do
    table "signature_input_types"
    repo Fleetms.Repo

    references do
      reference :inspection_form, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      argument :inspection_form_id, :uuid

      change manage_relationship(:inspection_form_id, :inspection_form, type: :append_and_remove)

      change fn changeset, _context ->
        name = Ash.Changeset.get_attribute(changeset, :name)

        if name && changeset.valid? do
          Ash.Changeset.change_attribute(changeset, :slug, Slug.slugify(name, separator: "_"))
        else
          changeset
        end
      end
    end

    update :update do
      primary? true
      require_atomic? false
      accept :*

      argument :inspection_form_id, :uuid

      change manage_relationship(:inspection_form_id, :inspection_form, type: :append_and_remove)

      change fn changeset, _context ->
        name = Ash.Changeset.get_attribute(changeset, :name)

        if name && changeset.valid? do
          Ash.Changeset.change_attribute(changeset, :slug, Slug.slugify(name, separator: "_"))
        else
          changeset
        end
      end
    end
  end

  multitenancy do
    strategy :context
  end
end
