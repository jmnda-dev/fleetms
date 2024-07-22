defmodule Fleetms.Inventory.PartManufacturer do
  use Ash.Resource,
    domain: Fleetms.Inventory,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 500
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  postgres do
    table "part_manufacturers"
    repo Fleetms.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]

    read :get_all

    read :get_by_id do
      argument :id, :uuid, allow_nil?: false

      filter expr(id == ^arg(:id))
    end
  end

  code_interface do

    define :get_all, action: :get_all
    define :get_by_id, action: :get_by_id, args: [:id], get?: true
  end

  identities do
    identity :unique_name, [:name]
  end

  multitenancy do
    strategy :context
  end
end
