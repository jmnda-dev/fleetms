defmodule Fleetms.VehicleManagement.VehiclePhoto do
  @moduledoc """
  A photo attached to a vehicle. Stores the storage keys for the display image
  and its thumbnail (written by the upload flow via `Fleetms.Storage`); the bytes
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
    table "vehicle_photos"
    repo Fleetms.Repo

    references do
      reference :vehicle, on_delete: :delete
    end
  end

  actions do
    defaults [:read]
    default_accept []

    create :create do
      primary? true
      accept [:image_key, :thumbnail_key, :caption, :vehicle_id]
    end

    # Processes an uploaded file into a stored display image + thumbnail, then
    # creates the photo. `source_path` is the uploaded temp file.
    create :upload do
      accept [:vehicle_id, :caption]
      argument :source_path, :string, allow_nil?: false

      change Fleetms.VehicleManagement.VehiclePhoto.Changes.ProcessUpload
    end

    update :update do
      primary? true
      accept [:caption]
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      change {DeleteStorageObjects, keys: [:image_key, :thumbnail_key]}
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

    attribute :image_key, :string do
      allow_nil? false
      public? true
      description "Storage key for the display-size image."
    end

    attribute :thumbnail_key, :string do
      allow_nil? false
      public? true
      description "Storage key for the thumbnail."
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
