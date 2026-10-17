defmodule Fleetms.VehicleManagement.VehicleDocument do
  @moduledoc """
  A document (registration, insurance, manual, …) attached to a vehicle. Stores
  the original filename for display and the storage key for retrieval; the bytes
  are removed from storage when the row is destroyed.
  """
  use Ash.Resource,
    otp_app: :fleetms,
    domain: Fleetms.VehicleManagement,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Fleetms.Permissions, only: [has_permission: 1]

  alias Fleetms.VehicleManagement.Changes.DeleteStorageObjects

  postgres do
    table "vehicle_documents"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  actions do
    defaults [:read]
    default_accept []

    read :get_by_id do
      get_by :id
    end

    read :list_by_vehicle do
      argument :vehicle_id, :uuid, allow_nil?: false
      filter expr(vehicle_id == ^arg(:vehicle_id))
      prepare build(sort: [inserted_at: :desc])
    end

    create :create do
      primary? true
      accept [:filename, :storage_key, :content_type, :byte_size, :caption, :vehicle_id]
    end

    # Stores an uploaded file, then creates the document. `source_path` is the
    # uploaded temp file.
    create :upload do
      accept [:filename, :content_type, :byte_size, :caption, :vehicle_id]
      argument :source_path, :string, allow_nil?: false

      change Fleetms.VehicleManagement.VehicleDocument.Changes.StoreUpload
    end

    update :update do
      primary? true
      accept [:filename, :caption]
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      change {DeleteStorageObjects, keys: [:storage_key]}
    end
  end

  policies do
    bypass actor_attribute_equals(:is_super_admin, true) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if has_permission(:view_vehicles)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if has_permission(:update_vehicle)
    end
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_primary_key :id

    attribute :filename, :string do
      allow_nil? false
      public? true
      description "Original, human-readable file name shown in the UI."
      constraints min_length: 1, max_length: 255
    end

    attribute :storage_key, :string do
      allow_nil? false
      public? true
      description "Storage key for retrieving the file."
    end

    attribute :content_type, :string do
      public? true
      constraints max_length: 255
    end

    attribute :byte_size, :integer do
      public? true
      constraints min: 0
    end

    attribute :caption, :string do
      public? true
      constraints max_length: 1000
    end

    timestamps()
  end

  relationships do
    belongs_to :vehicle, Fleetms.VehicleManagement.Vehicle do
      allow_nil? false
      public? true
    end
  end
end
