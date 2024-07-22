defmodule Fleetms.Inspection.Form.DropdownInput do
  use Ash.Resource,
    domain: Fleetms.Inspection,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    attribute :type, :atom do
      allow_nil? false
      writable? false
      constraints one_of: [:dropdown_input]
      default :dropdown_input
    end

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 50
    end

    attribute :help_text, :string do
      public? true
      allow_nil? true
      constraints min_length: 0, max_length: 500
    end

    attribute :options, {:array, Fleetms.Inspection.Form.InputChoice} do
      public? true
    end

    # TODO: Revise this attribute. Perhaps it might not be required, since
    # the options have a fail_if_selected attribute, which creates a
    # conflict with this attribute and the :comments_required_on_fail attribute.
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
    belongs_to :inspection_form, Fleetms.Inspection.InspectionForm do
      allow_nil? false
    end
  end

  postgres do
    table "dropdown_inputs"
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

      argument :options, {:array, :map}

      argument :inspection_form_id, :uuid

      change manage_relationship(:inspection_form_id, :inspection_form, type: :append_and_remove)
      change set_attribute(:options, arg(:options))

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

      argument :options, {:array, :map}

      argument :inspection_form_id, :uuid

      change manage_relationship(:inspection_form_id, :inspection_form, type: :append_and_remove)
      change set_attribute(:options, arg(:options))

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
