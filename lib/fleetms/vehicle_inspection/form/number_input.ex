defmodule Fleetms.VehicleInspection.Form.NumberInput do
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
      constraints one_of: [:number_input, :mileage]
      default :number_input
    end

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

    attribute :help_text, :string do
      allow_nil? true
      public? true
      constraints min_length: 0, max_length: 500
    end

    attribute :comment_required_on_pass, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :comment_required_on_fail, :boolean do
      allow_nil? false
      public? true
      default false
    end
  end

  relationships do
    belongs_to :inspection_form, Fleetms.VehicleInspection.InspectionForm do
      allow_nil? false
    end
  end

  postgres do
    table "number_inputs"
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
