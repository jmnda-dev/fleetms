defmodule Fleetms.Inventory.PartPhoto do
  use Ash.Resource,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read]

    create :create do
      accept :*
      primary? true
      argument :part_id, :uuid

      change manage_relationship(:part_id, :part, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false
      accept :*
      argument :part_id, :uuid

      change manage_relationship(:part_id, :part, type: :append_and_remove)
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_record ->
          %__MODULE_{filename: filename, part_id: part_id} = deleted_record
          scope = %{id: part_id}
          Fleetms.PartPhoto.delete({filename, scope})
          {:ok, deleted_record}
        end)
      end
    end
  end

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
      description "The caption of the work order photo."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :part, Fleetms.Inventory.Part do
      allow_nil? false
    end
  end

  postgres do
    table "part_photos"
    repo Fleetms.Repo

    references do
      reference :part, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
