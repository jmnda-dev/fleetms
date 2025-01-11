defmodule Fleetms.VehicleManagement.VehicleDocument do
  @moduledoc """
  Defines the vehicle document resource.
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
      description "The humanized name of the file."
    end

    attribute :storage_filename, :string do
      allow_nil? false
      public? true
      description "The name of the file."
    end

    attribute :file_type, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 100
      description "The file type of the vehicle document."
    end

    attribute :caption, :string do
      allow_nil? true
      public? true
      constraints min_length: 1, max_length: 1000
      description "The caption of the vehicle document."
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

    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false

      filter expr(vehicle_id == ^arg(:vehicle_id))
    end

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false
      get? true

      filter expr(id == ^arg(:id))
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*

      argument :vehicle_id, :uuid

      change manage_relationship(:vehicle_id, :vehicle, type: :append_and_remove)
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_record ->
          %__MODULE_{storage_filename: filename, vehicle_id: vehicle_id} = deleted_record
          scope = %{id: vehicle_id}
          Fleetms.VehicleDocument.delete({filename, scope})
          {:ok, deleted_record}
        end)
      end
    end
  end

  postgres do
    table "vehicle_documents"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
