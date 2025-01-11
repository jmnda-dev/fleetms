defmodule Fleetms.VehicleInspection.InspectionForm do
  use Ash.Resource,
    domain: Fleetms.VehicleInspection,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  alias Fleetms.Accounts.User.Policies.{IsAdmin, IsFleetManager}

  attributes do
    uuid_primary_key :id

    attribute :slug, :string do
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :labels, {:array, :string} do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :inspection_submissions, Fleetms.VehicleInspection.InspectionSubmission

    many_to_many :vehicles, Fleetms.VehicleManagement.Vehicle do
      domain Fleetms.VehicleManagement
      through Fleetms.VehicleInspection.InspectionFormVehicle
      source_attribute_on_join_resource :inspection_form_id
      destination_attribute_on_join_resource :vehicle_id
    end

    has_many :radio_inputs, Fleetms.VehicleInspection.Form.RadioInput
    has_many :dropdown_inputs, Fleetms.VehicleInspection.Form.DropdownInput
    has_many :number_inputs, Fleetms.VehicleInspection.Form.NumberInput
    has_many :signature_inputs, Fleetms.VehicleInspection.Form.SignatureInput
    has_many :text_inputs, Fleetms.VehicleInspection.Form.TextInput
  end

  postgres do
    table "inspection_forms"
    repo Fleetms.Repo
  end

  policies do
    policy action_type(:action) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action(:update) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end

    policy action(:destroy) do
      authorize_if IsAdmin
      authorize_if IsFleetManager
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title]

      change fn changeset, _context ->
        title = Ash.Changeset.get_attribute(changeset, :title)

        if title && changeset.valid? do
          Ash.Changeset.change_attribute(changeset, :slug, Slug.slugify(title, separator: "_"))
        else
          changeset
        end
      end
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:title]

      argument :radio_inputs, {:array, :map}

      argument :dropdown_inputs, {:array, :map}

      argument :number_inputs, {:array, :map}

      argument :signature_inputs, {:array, :map}

      argument :text_inputs, {:array, :map}

      change fn changeset, _context ->
        title = Ash.Changeset.get_attribute(changeset, :title)

        if title && changeset.valid? do
          Ash.Changeset.change_attribute(changeset, :slug, Slug.slugify(title, separator: "_"))
        else
          changeset
        end
      end

      change manage_relationship(:radio_inputs, :radio_inputs, type: :direct_control)

      change manage_relationship(:dropdown_inputs, :dropdown_inputs, type: :direct_control)

      change manage_relationship(:number_inputs, :number_inputs, type: :direct_control)

      change manage_relationship(:signature_inputs, :signature_inputs, type: :direct_control)
      change manage_relationship(:text_inputs, :text_inputs, type: :direct_control)
    end

    read :list do
      primary? true
      pagination offset?: true, default_limit: 50, countable: true
    end

    read :get_all

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))

      prepare build(
                load: [
                  :radio_inputs,
                  :dropdown_inputs,
                  :number_inputs,
                  :signature_inputs
                ]
              )
    end
  end

  code_interface do
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
    define :get_all, action: :get_all
  end

  identities do
    identity :unique_title, [:title]
  end

  multitenancy do
    strategy :context
  end
end
