defmodule Fleetms.FuelManagement.FuelHistoryPhoto do
  use Ash.Resource,
    domain: Fleetms.FuelManagement,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read]

    create :create do
      accept :*
      primary? true
      argument :fuel_history_id, :uuid

      change manage_relationship(:fuel_history_id, :fuel_history, type: :append_and_remove)
    end

    update :update do
      accept :*
      require_atomic? false
      primary? true
      argument :fuel_history_id, :uuid

      change manage_relationship(:fuel_history_id, :fuel_history, type: :append_and_remove)
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_record ->
          %__MODULE_{filename: filename, fuel_history_id: fuel_history_id} = deleted_record
          scope = %{id: fuel_history_id}
          Fleetms.FuelHistoryPhoto.delete({filename, scope})
          {:ok, deleted_record}
        end)
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :filename, :string do
      public? true
      allow_nil? false
      description "The name of the file."
    end

    attribute :caption, :string do
      public? true
      allow_nil? true
      constraints min_length: 1, max_length: 1000
      description "The caption of the fuel history photo."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :fuel_history, Fleetms.FuelManagement.FuelHistory do
      allow_nil? false
    end
  end

  postgres do
    table "fuel_history_photos"
    repo Fleetms.Repo

    references do
      reference :fuel_history, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
