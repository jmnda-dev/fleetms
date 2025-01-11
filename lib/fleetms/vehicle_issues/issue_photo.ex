defmodule Fleetms.VehicleIssues.IssuePhoto do
  use Ash.Resource,
    domain: Fleetms.VehicleIssues,
    data_layer: AshPostgres.DataLayer

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept :*

      argument :issue_id, :uuid

      change manage_relationship(:issue_id, :issue, type: :append_and_remove)
    end

    update :update do
      primary? true
      require_atomic? false
      accept :*
      argument :issue_id, :uuid

      change manage_relationship(:issue_id, :issue, type: :append_and_remove)
    end

    destroy :destroy do
      require_atomic? false
      primary? true

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn changeset, deleted_record ->
          %__MODULE_{filename: filename, issue_id: issue_id} = deleted_record
          scope = %{id: issue_id}
          Fleetms.IssuePhoto.delete({filename, scope})
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
      description "The caption of the issue photo."
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :issue, Fleetms.VehicleIssues.Issue do
      allow_nil? false
    end
  end

  postgres do
    table "issue_photos"
    repo Fleetms.Repo

    references do
      reference :issue, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end
end
