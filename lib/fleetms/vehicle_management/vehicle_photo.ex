defmodule Fleetms.VehicleManagement.VehiclePhoto do
  @moduledoc """
  Defines the vehicle photo resource, as an embedded resource.
  """
  use Ash.Resource,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [
      Ash.Policy.Authorizer
    ]

  attributes do
    uuid_primary_key :id

    attribute :filename, :string do
      allow_nil? false
      public? true
      description "The name of the file."
    end

    attribute :caption, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
      description "The caption of the vehicle photo."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:update) do
      authorize_if always()
    end

    policy action_type(:destroy) do
      authorize_if always()
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept :*
      argument :vehicle_id, :uuid

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*
      argument :vehicle_id, :uuid

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_record ->
          %__MODULE_{filename: filename, vehicle_id: vehicle_id} = deleted_record
          scope = %{id: vehicle_id}
          Fleetms.VehiclePhoto.delete({filename, scope})
          {:ok, deleted_record}
        end)
      end
    end
  end

  postgres do
    table "vehicle_photos"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
