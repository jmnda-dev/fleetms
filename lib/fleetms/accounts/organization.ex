defmodule Fleetms.Accounts.Organization do
  @moduledoc """
  A Organization resource
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Fleetms.Accounts

  @schema_prefix "fleetms_org_"

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    attribute :phone_number, :string do
      allow_nil? true
      public? true
      constraints min_length: 10, max_length: 20
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :users, Fleetms.Accounts.User
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  identities do
    identity :unique_name, [:name] do
      eager_check? true
    end
  end

  postgres do
    table "organizations"
    repo Fleetms.Repo

    manage_tenant do
      template [@schema_prefix, :id]
    end
  end
end
