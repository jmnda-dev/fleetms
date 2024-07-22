defmodule Fleetms.Common.Sequence do
  use Ash.Resource,
    domain: Fleetms.Common,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :resource_name, :atom do
      allow_nil? false
      public? true
      constraints one_of: Fleetms.Enums.resource_names()
      description "The name of the resource we are keeping track of the sequence count."
      writable? false
    end

    attribute :current_count, :integer do
      public? true
      allow_nil? false
      writable? false
    end
  end

  actions do
    defaults [:read, create: :*]

    read :issue_resource_sequence do
      get? true
      filter expr(resource_name == :issue)

      prepare fn query, _context ->
        Ash.Query.lock(query, "FOR UPDATE")
      end
    end

    read :inspection_resource_sequence do
      get? true
      filter expr(resource_name == :inspection)

      prepare fn query, _context ->
        Ash.Query.lock(query, "FOR UPDATE")
      end
    end

    read :work_order_resource_sequence do
      get? true
      filter expr(resource_name == :work_order)

      prepare fn query, _context ->
        Ash.Query.lock(query, "FOR UPDATE")
      end
    end

    update :increment do
      primary? true
      require_atomic? false
      change increment(:current_count)
    end
  end

  identities do
    identity :unique_resource_name, [:resource_name]
  end

  code_interface do
    define :increment, action: :increment, args: []
    define :get_issue_resource_sequence, action: :issue_resource_sequence, args: []
    define :get_inspection_resource_sequence, action: :inspection_resource_sequence, args: []
    define :get_work_order_resource_sequence, action: :work_order_resource_sequence, args: []
  end

  postgres do
    table "sequences"
    repo Fleetms.Repo
  end

  multitenancy do
    strategy :context
  end
end
