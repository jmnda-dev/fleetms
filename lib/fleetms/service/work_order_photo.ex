defmodule Fleetms.Service.WorkOrderPhoto do
  use Ash.Resource,
    domain: Fleetms.Service,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept :*
      argument :work_order_id, :uuid

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)
    end

    update :update do
      require_atomic? false
      primary? true
      accept :*
      argument :work_order_id, :uuid

      change manage_relationship(:work_order_id, :work_order, type: :append_and_remove)
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_record ->
          %__MODULE_{filename: filename, work_order_id: work_order_id} = deleted_record
          scope = %{id: work_order_id}
          Fleetms.WorkOrderPhoto.delete({filename, scope})
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
    belongs_to :work_order, Fleetms.Service.WorkOrder do
      allow_nil? false
    end
  end

  postgres do
    table "work_order_photos"
    repo Fleetms.Repo

    references do
      reference :work_order, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
